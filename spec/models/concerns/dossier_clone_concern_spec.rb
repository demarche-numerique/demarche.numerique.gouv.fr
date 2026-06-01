# frozen_string_literal: true

RSpec.describe DossierCloneConcern do
  let(:procedure) do
    create(:procedure, types_de_champ_public:, types_de_champ_private:).tap { |it| it.publish!(it.administrateurs.first) }
  end
  let(:types_de_champ_public) do
    [
      { type: :text, libelle: "Un champ text", stable_id: 99 },
      { type: :text, libelle: "Un autre champ text", stable_id: 991 },
      { type: :yes_no, libelle: "Un champ yes no", stable_id: 992 },
      { type: :repetition, libelle: "Un champ répétable", stable_id: 993, mandatory: true, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
    ]
  end
  let(:types_de_champ_private) { [] }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }

  describe '#clone' do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let(:types_de_champ_public) { [{}] }
    let(:types_de_champ_private) { [] }
    subject(:new_dossier) { dossier.clone }

    it 'resets most of the attributes for the cloned dossier' do
      expect(new_dossier.id).not_to eq(dossier.id)
      expect(new_dossier.api_entreprise_job_exceptions).to be_nil
      expect(new_dossier.archived).to be_falsey
      expect(new_dossier.brouillon_close_to_expiration_notice_sent_at).to be_nil
      expect(new_dossier.conservation_extension).to eq(0.seconds)
      expect(new_dossier.declarative_triggered_at).to be_nil
      expect(new_dossier.deleted_user_email_never_send).to be_nil
      expect(new_dossier.depose_at).to be_nil
      expect(new_dossier.en_construction_at).to be_nil
      expect(new_dossier.en_instruction_at).to be_nil
      expect(new_dossier.for_procedure_preview).to be_falsey
      expect(new_dossier.groupe_instructeur_updated_at).to be_nil
      expect(new_dossier.hidden_by_administration_at).to be_nil
      expect(new_dossier.hidden_by_reason).to be_nil
      expect(new_dossier.hidden_by_user_at).to be_nil
      expect(new_dossier.identity_updated_at).to be_nil
      expect(new_dossier.last_avis_updated_at).to be_nil
      expect(new_dossier.last_champ_private_updated_at).to be_nil
      expect(new_dossier.last_champ_updated_at).to be_nil
      expect(new_dossier.last_commentaire_updated_at).to be_nil
      expect(new_dossier.last_commentaire_piece_jointe_updated_at).to be_nil
      expect(new_dossier.motivation).to be_nil
      expect(new_dossier.processed_at).to be_nil
    end

    it "updates search terms" do
      # In spec, dossier and flag reference are created just before deep clone,
      # which keep the flag reference from the original, pointing to the original id.
      # We have to remove the flag reference before the clone
      dossier.remove_instance_variable(:@debounce_index_search_terms_flag_kredis_flag)

      perform_enqueued_jobs(only: DossierIndexSearchTermsJob) do
        subject
      end

      sql = "SELECT search_terms, private_search_terms FROM dossiers where id = :id"
      result = Dossier.connection.execute(Dossier.sanitize_sql_array([sql, id: new_dossier.id])).first

      expect(result["search_terms"]).to match(dossier.user.email)
      expect(result["private_search_terms"]).to eq("")
    end

    context 'copies some attributes' do
      it "copies or reset attributes" do
        expect(new_dossier.groupe_instructeur).to be_nil
        expect(new_dossier.autorisation_donnees).to eq(dossier.autorisation_donnees)
        expect(new_dossier.revision_id).to eq(dossier.revision_id)
        expect(new_dossier.user_id).to eq(dossier.user_id)
      end
    end

    context 'forces some attributes' do
      let(:dossier) { create(:dossier, :accepte) }

      it do
        expect(new_dossier.brouillon?).to eq(true)
        expect(new_dossier.parent_dossier).to eq(dossier)
      end

      context 'destroy parent' do
        before { new_dossier }

        it 'clean fk' do
          expect { dossier.destroy }.to change { new_dossier.reload.parent_dossier_id }.from(dossier.id).to(nil)
        end
      end
    end

    context 'procedure with_individual' do
      let(:procedure) { create(:procedure, :for_individual) }
      it do
        expect(new_dossier.individual.slice(:nom, :prenom, :gender)).to eq(dossier.individual.slice(:nom, :prenom, :gender))
        expect(new_dossier.individual.id).not_to eq(dossier.individual.id)
      end
    end

    context 'procedure with etablissement' do
      let(:dossier) { create(:dossier, :with_entreprise) }
      it do
        expect(new_dossier.etablissement.slice(:siret)).to eq(dossier.etablissement.slice(:siret))
        expect(new_dossier.etablissement.id).not_to eq(dossier.etablissement.id)
      end
    end

    describe 'champs' do
      it { expect(new_dossier.id).not_to eq(dossier.id) }

      context 'public are duplicated' do
        it do
          expect(new_dossier.project_champs_public.count).to eq(dossier.project_champs_public.count)
          expect(new_dossier.project_champs_public.map(&:id)).not_to eq(dossier.project_champs_public.map(&:id))
        end

        it 'keeps champs.values' do
          original_first_champ = dossier.project_champs_public.first
          original_first_champ.update!(value: 'kthxbye')

          expect(new_dossier.project_champs_public.first.value).to eq(original_first_champ.value)
        end

        context 'for Champs::Repetition with rows, original_champ.repetition and rows are duped' do
          let(:types_de_champ_public) { [{ type: :repetition, children: [{}, {}] }] }
          let(:champ_repetition) { dossier.project_champs_public.find(&:repetition?) }
          let(:cloned_champ_repetition) { new_dossier.project_champs_public.find(&:repetition?) }

          it do
            expect(cloned_champ_repetition.rows.flatten.count).to eq(4)
            expect(cloned_champ_repetition.rows.flatten.map(&:id)).not_to eq(champ_repetition.rows.flatten.map(&:id))
            expect(cloned_champ_repetition.row_ids).to eq(champ_repetition.row_ids)
          end
        end

        context 'for Champs::CarteChamp with geo areas, original_champ.geo_areas are duped' do
          let(:types_de_champ_public) { [{ type: :carte }] }
          let(:champ_carte) { dossier.champs.first }
          let(:cloned_champ_carte) { new_dossier.champs.first }

          it do
            expect(cloned_champ_carte.geo_areas.count).to eq(2)
            expect(cloned_champ_carte.geo_areas.ids).not_to eq(champ_carte.geo_areas.ids)
          end
        end

        context 'for Champs::SiretChamp, original_champ.etablissement is duped' do
          let(:types_de_champ_public) { [{ type: :siret }] }
          let(:champ_siret) { dossier.champs.first }
          let(:cloned_champ_siret) { new_dossier.champs.first }

          it do
            expect(champ_siret.etablissement).not_to be_nil
            expect(cloned_champ_siret.etablissement.id).not_to eq(champ_siret.etablissement.id)
          end
        end

        context 'for Champs::PieceJustificative, original_champ.piece_justificative_file is duped' do
          let(:types_de_champ_public) { [{ type: :piece_justificative }] }
          let(:champ_piece_justificative) { dossier.champs.first }
          let(:cloned_champ_piece_justificative) { new_dossier.champs.first }

          it { expect(cloned_champ_piece_justificative.piece_justificative_file.first.blob).to eq(champ_piece_justificative.piece_justificative_file.first.blob) }
        end

        context 'for Champs::AddressChamp, original_champ.data is duped' do
          let(:types_de_champ_public) { [{ type: :address }] }
          let(:champ_address) { dossier.champs.first }
          let(:cloned_champ_address) { new_dossier.champs.first }

          before { champ_address.update(external_id: 'Address', data: { city_code: '75019' }) }

          it do
            expect(champ_address.data).not_to be_nil
            expect(champ_address.external_id).not_to be_nil
            expect(cloned_champ_address.external_id).to eq(champ_address.external_id)
            expect(cloned_champ_address.data).to eq(champ_address.data)
          end
        end
      end

      context 'private are renewd' do
        let(:types_de_champ_private) { [{}] }

        it 'reset champs private values' do
          expect(new_dossier.project_champs_private.count).to eq(dossier.project_champs_private.count)
          expect(new_dossier.project_champs_private.map(&:id)).not_to eq(dossier.project_champs_private.map(&:id))
          original_first_champs_private = dossier.project_champs_private.first
          original_first_champs_private.update!(value: 'kthxbye')

          expect(new_dossier.project_champs_private.first.value).not_to eq(original_first_champs_private.value)
          expect(new_dossier.project_champs_private.first.value).to eq(nil)
        end
      end
    end
  end
end
