# frozen_string_literal: true

describe InstructeursImportService do
  describe '#import_groupes' do
    let(:procedure) { create(:procedure) }

    let(:procedure_groupes) do
      procedure
        .groupe_instructeurs
        .map { |gi| [gi.label, gi.instructeurs.map(&:email)] }
        .to_h
    end

    subject { described_class.import_groupes(procedure, lines) }

    context 'nominal case' do
      let(:lines) do
        [
          { "groupe" => "Auvergne Rhone-Alpes", "email" => "john@lennon.fr" },
          { "groupe" => "  Occitanie  ", "email" => "paul@mccartney.uk" },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
        ]
      end

      it 'imports groupes' do
        _, errors = subject

        expect(procedure_groupes.keys).to contain_exactly("Auvergne Rhone-Alpes", "Occitanie", "défaut")
        expect(procedure_groupes["Auvergne Rhone-Alpes"]).to contain_exactly("john@lennon.fr")
        expect(procedure_groupes["Occitanie"]).to contain_exactly("paul@mccartney.uk", "ringo@starr.uk")
        expect(procedure_groupes["défaut"]).to be_empty

        expect(errors).to match_array([])
      end
    end

    context 'when group already exists' do
      let!(:gi) { create(:groupe_instructeur, label: 'Occitanie', procedure: procedure) }
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
        ]
      end

      before do
        gi.instructeurs << create(:instructeur, email: 'george@harisson.uk')
      end

      it 'adds instructeur to existing groupe' do
        subject

        expect(procedure_groupes.keys).to contain_exactly("Occitanie", "défaut")
        expect(procedure_groupes["Occitanie"]).to contain_exactly("george@harisson.uk", "ringo@starr.uk")
        expect(procedure_groupes["défaut"]).to be_empty
      end
    end

    context 'when an email is malformed' do
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "paul" },
          { "groupe" => "Occitanie", "email" => "  Paul@mccartney.uk " },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
        ]
      end

      it 'ignores or corrects' do
        _, errors = subject

        expect(procedure_groupes.keys).to contain_exactly("Occitanie", "défaut")
        expect(procedure_groupes["Occitanie"]).to contain_exactly("paul@mccartney.uk", "ringo@starr.uk")
        expect(procedure_groupes["défaut"]).to be_empty

        expect(errors).to contain_exactly("paul")
      end
    end

    context 'when an instructeur already exists' do
      let!(:instructeur) { create(:instructeur) }
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => instructeur.email },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
        ]
      end

      it 'reuses instructeur' do
        subject

        expect(procedure_groupes.keys).to contain_exactly("Occitanie", "défaut")
        expect(procedure_groupes["Occitanie"]).to contain_exactly(instructeur.email, "ringo@starr.uk")
        expect(procedure_groupes["défaut"]).to be_empty
      end
    end

    context 'when there are 2 emails of same instructeur to be imported' do
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
        ]
      end

      it 'ignores duplicated instructeur' do
        subject

        expect(procedure_groupes.keys).to contain_exactly("Occitanie", "défaut")
        expect(procedure_groupes["Occitanie"]).to contain_exactly("ringo@starr.uk")
        expect(procedure_groupes["défaut"]).to be_empty
      end
    end

    context 'when overwrite is true' do
      let!(:gi_occitanie) { create(:groupe_instructeur, label: 'Occitanie', procedure: procedure) }
      let!(:instructeur_to_keep) { create(:instructeur, email: 'ringo@starr.uk') }
      let!(:instructeur_to_remove) { create(:instructeur, email: 'george@harrison.uk') }

      before do
        gi_occitanie.instructeurs << instructeur_to_keep
        gi_occitanie.instructeurs << instructeur_to_remove
      end

      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
          { "groupe" => "Occitanie", "email" => "john@lennon.fr" },
        ]
      end

      subject { described_class.import_groupes(procedure, lines, overwrite: true) }

      it 'keeps instructeurs in csv, adds new ones, removes others' do
        subject

        # The empty "défaut" group is deleted during overwrite, leaving only "Occitanie".
        # With a single group remaining, routing collapses and the group is renamed to "défaut".
        expect(procedure_groupes["défaut"]).to contain_exactly("ringo@starr.uk", "john@lennon.fr")
      end

      it 'returns removed instructeurs by groupe' do
        _, _, _, removed_groupes_by_instructeur = subject

        expect(removed_groupes_by_instructeur.keys).to contain_exactly(instructeur_to_remove)
        expect(removed_groupes_by_instructeur[instructeur_to_remove].map(&:label)).to contain_exactly('Occitanie')
      end

      context 'when a group in csv has dossiers' do
        let!(:dossier) { create(:dossier, groupe_instructeur: gi_occitanie, procedure: procedure) }

        it 'removes instructeurs not in csv even if the group has dossiers' do
          subject

          # Routing collapses (défaut deleted, only Occitanie remains → renamed to "défaut")
          expect(procedure_groupes["défaut"]).to contain_exactly("ringo@starr.uk", "john@lennon.fr")
          expect(procedure_groupes["défaut"]).not_to include("george@harrison.uk")
        end
      end

      context 'when a groupe is not mentioned in csv' do
        let!(:gi_other) { create(:groupe_instructeur, label: 'Bretagne', procedure: procedure) }
        let!(:instructeur_in_other) { create(:instructeur, email: 'breizh@gouv.fr') }

        before { gi_other.instructeurs << instructeur_in_other }

        it 'deletes groups not in csv when they have no dossiers' do
          subject

          expect(procedure.groupe_instructeurs.map(&:label)).not_to include('Bretagne')
        end

        it 'returns removed instructeurs from deleted group' do
          _, _, _, removed_groupes_by_instructeur = subject

          expect(removed_groupes_by_instructeur.keys).to include(instructeur_in_other)
          expect(removed_groupes_by_instructeur[instructeur_in_other].map(&:label)).to include('Bretagne')
        end

        context 'when a group not in csv has dossiers' do
          let!(:dossier) { create(:dossier, groupe_instructeur: gi_other, procedure: procedure) }

          it 'empties the group instead of deleting it' do
            subject

            expect(procedure.groupe_instructeurs.map(&:label)).to include('Bretagne')
            expect(procedure_groupes["Bretagne"]).to be_empty
          end

          context 'when an administrateur is provided' do
            let!(:administrateur) { create(:administrateur) }

            subject { described_class.import_groupes(procedure, lines, overwrite: true, administrateur: administrateur) }

            it 'assigns the administrateur as instructeur to keep the group staffed' do
              subject

              expect(procedure_groupes["Bretagne"]).to contain_exactly(administrateur.instructeur.email)
            end
          end
        end
      end

      context 'when only one group remains after overwrite' do
        before { procedure.update!(routing_enabled: true) }

        it 'disables routing and resets the remaining group as defaut' do
          subject

          procedure.reload
          expect(procedure.routing_enabled).to be false
          expect(procedure.routing_alert).to be false
          expect(procedure.defaut_groupe_instructeur.label).to eq(GroupeInstructeur::DEFAUT_LABEL)
          expect(procedure.defaut_groupe_instructeur.routing_rule).to be_nil
        end
      end

      context 'when all csv emails for a group are invalid' do
        let(:lines) do
          [
            { "groupe" => "Occitanie", "email" => "not-an-email" },
          ]
        end

        it 'does not remove existing instructeurs to preserve at least one' do
          subject

          # Routing collapses (only Occitanie remains after défaut is deleted), group renamed to "défaut"
          expect(procedure_groupes["défaut"]).to include("ringo@starr.uk")
        end
      end
    end

    context 'when label of group is empty' do
      let(:lines) do
        [
          { "groupe" => "", "email" => "ringo@starr.uk" },
          { "groupe" => " ", "email" => "paul@starr.uk" },
        ]
      end

      it 'ignores instructeur' do
        _, errors = subject

        expect(procedure_groupes.keys).to contain_exactly("défaut")
        expect(procedure_groupes["défaut"]).to be_empty

        expect(errors).to contain_exactly("ringo@starr.uk", "paul@starr.uk")
      end
    end
  end

  describe '#import_instructeurs' do
    let(:procedure_non_routee) { create(:procedure) }

    subject { described_class.import_instructeurs(procedure_non_routee, emails) }

    context 'nominal case' do
      let(:emails) { [{ "email" => "john@lennon.fr" }, { "email" => "paul@mccartney.uk" }, { "email" => "ringo@starr.uk" }] }

      it 'imports instructeurs' do
        _, errors = subject
        expect(procedure_non_routee.defaut_groupe_instructeur.instructeurs.pluck(:email)).to contain_exactly("john@lennon.fr", "paul@mccartney.uk", "ringo@starr.uk")

        expect(errors).to match_array([])
      end
    end

    context 'when overwrite is true' do
      let!(:instructeur_to_keep) { create(:instructeur, email: 'john@lennon.fr') }
      let!(:instructeur_to_remove) { create(:instructeur, email: 'paul@mccartney.uk') }
      let(:groupe) { procedure_non_routee.defaut_groupe_instructeur }

      before do
        groupe.instructeurs << instructeur_to_keep
        groupe.instructeurs << instructeur_to_remove
      end

      let(:emails) { [{ "email" => "john@lennon.fr" }, { "email" => "ringo@starr.uk" }] }

      subject { described_class.import_instructeurs(procedure_non_routee, emails, overwrite: true) }

      it 'keeps instructeurs in csv, adds new ones, removes others' do
        subject

        expect(groupe.instructeurs.pluck(:email)).to contain_exactly("john@lennon.fr", "ringo@starr.uk")
      end

      it 'returns removed instructeurs' do
        _, _, removed_instructeurs = subject

        expect(removed_instructeurs).to contain_exactly(instructeur_to_remove)
      end

      context 'when all csv emails are invalid' do
        let(:emails) { [{ "email" => "not-an-email" }] }

        it 'does not remove existing instructeurs to preserve at least one' do
          subject

          expect(groupe.instructeurs.pluck(:email)).to contain_exactly("john@lennon.fr", "paul@mccartney.uk")
        end
      end
    end
  end
end
