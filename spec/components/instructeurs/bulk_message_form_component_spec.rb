# frozen_string_literal: true

describe Instructeurs::BulkMessageFormComponent, type: :component do
  let(:component) { described_class.new(procedure:, current_instructeur:, dossiers_count_per_groupe_instructeur:) }
  let(:current_instructeur) { create(:instructeur) }

  describe ".default_dossiers_count" do
    let(:procedure) { create(:procedure) }
    subject { component.default_dossiers_count }

    context 'when routing' do
      let(:procedure) { create(:procedure, routing_enabled: true, groupe_instructeurs: [gi_1, gi_2]) }
      let(:dossiers_count_per_groupe_instructeur) do
        {
          nil: 10,
          gi_1.id => 15,
          gi_2.id => 20,
        }
      end

      context 'when enabled and instructeur in all groupes' do
        let(:gi_1) { create(:groupe_instructeur, instructeurs: [current_instructeur]) }
        let(:gi_2) { create(:groupe_instructeur, instructeurs: [current_instructeur]) }

        it 'counts all (including count for dossier without groupe instructeur)' do
          expect(subject).to eq(dossiers_count_per_groupe_instructeur.values.sum)
        end
      end

      context 'when enabled and instructeur in groupe' do
        let(:gi_1) { create(:groupe_instructeur, instructeurs: [current_instructeur]) }
        let(:gi_2) { create(:groupe_instructeur, instructeurs: [create(:instructeur)]) }

        it 'counts only dossiers for his groupe_instructeurs' do
          expect(subject).to eq(dossiers_count_per_groupe_instructeur[gi_1.id])
        end
      end
    end

    context 'when routing disabled' do
      let(:procedure) { create(:procedure, routing_enabled: false) }
      let(:dossiers_count_per_groupe_instructeur) do
        {
          nil: 10,
          procedure.groupe_instructeurs.first.id => 15,
        }
      end
      it 'counts all (including count for dossier without groupe instructeur)' do
        expect(subject).to eq(dossiers_count_per_groupe_instructeur.values.sum)
      end
    end
  end

  describe 'render' do
    let(:dossiers_count_per_groupe_instructeur) do
      procedure.dossiers.state_brouillon.group(:groupe_instructeur_id).count
    end
    subject { render_inline(component).to_html }

    context 'when group instructeur has a brouillon and has current instructeurs part of it' do
      let(:procedure) { create(:procedure, routing_enabled: true, instructeurs: [current_instructeur]) }
      it 'is expected to render the groupe' do
        create(:dossier, :brouillon, procedure:, groupe_instructeur: procedure.groupe_instructeurs.first)
        expect(subject).not_to have_selector("hr.fr-hr") # no other group from current_instructeur having brouillon, this part is not rendered
        expect(subject).to have_selector("input#bulk_message_groupe_instructeur_ids_#{procedure.groupe_instructeurs.first.id}[checked=checked]")
        expect(subject).to have_content("1 usager (vous êtes présent dans ce groupe instructeurs)")
      end
    end

    context 'when group instructeur has a brouillon but current instructeurs is not part of it' do
      let(:procedure) { create(:procedure, routing_enabled: true, instructeurs: []) }

      it 'is expected to render the groupe' do
        create(:dossier, :brouillon, procedure:, groupe_instructeur: procedure.groupe_instructeurs.first)
        create(:dossier, :brouillon, procedure:, groupe_instructeur: procedure.groupe_instructeurs.first)
        expect(subject).to have_selector("hr.fr-hr") # groupes having brouillon not part of current instructeur are separated by hr
        expect(subject).not_to have_selector("input#bulk_message_groupe_instructeur_ids_#{procedure.groupe_instructeurs.first.id}[checked=checked]")
        expect(subject).to have_content("2 usagers (vous n'êtes pas présent dans ce groupe instructeurs)")
      end
    end

    context 'when dossier without group exists' do
      let(:procedure) { create(:procedure, routing_enabled: true, instructeurs: []) }

      it 'is expected to render the groupe' do
        create(:dossier, :brouillon, procedure:, groupe_instructeur: nil)
        expect(subject).to have_content("Contacter également l’usager qui n’a pas encore renseigné le(s) champ(s) de routage")
      end
    end

    describe 'select all or not' do
      context 'when groupe_instructeur < treshold' do
        before { allow(component).to receive(:render_select_all?).and_return(false) }
        let(:procedure) { create(:procedure, routing_enabled: true, instructeurs: []) }

        it { is_expected.not_to have_selector("#bulk-message-select-all") }
      end

      context 'when groupe_instructeur > treshold' do
        before { allow(component).to receive(:render_select_all?).and_return(true) }
        let(:procedure) { create(:procedure, routing_enabled: true, instructeurs: []) }

        it { is_expected.to have_selector("#bulk-message-select-all") }
      end
    end
  end
end
