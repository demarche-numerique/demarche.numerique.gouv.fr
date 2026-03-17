# frozen_string_literal: true

describe BulkRouteJob, type: :job do
  include Logic
  describe 'perform' do
    let(:admin) { administrateurs(:default_admin) }
    let!(:procedure) do
      create(:procedure,
             types_de_champ_public: [
               { type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] },
               { type: :text, libelle: 'Un champ texte' },
             ],
             administrateurs: [admin])
    end

    let!(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }
    let!(:dossier1) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let!(:dossier2) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let!(:dossier3) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }
    let!(:groupe_instructeur_paris) { create(:groupe_instructeur, procedure: procedure, label: 'Paris', routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Paris'))) }
    let!(:groupe_instructeur_lyon) { create(:groupe_instructeur, procedure: procedure, label: 'Lyon', routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon'))) }
    let!(:groupe_instructeur_marseille) { create(:groupe_instructeur, procedure: procedure, label: 'Marseille', routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Marseille'))) }

    subject do
      BulkRouteJob.perform_now(procedure)
    end

    before do
      procedure.update_all_groupes_rule_statuses
      dossier1.champs.first.update(value: 'Paris')
      dossier2.champs.first.update(value: 'Lyon')
      dossier3.champs.first.update(value: 'Marseille')
      subject
    end

    it 'routes only dossiers en construction or en instruction' do
      expect(dossier1.reload.groupe_instructeur.label).to eq 'Paris'
      expect(dossier1.dossier_assignment.mode).to eq 'bulk_routing'
      expect(dossier2.reload.groupe_instructeur.reload.label).to eq 'Lyon'
      expect(dossier2.dossier_assignment.mode).to eq 'bulk_routing'
      expect(dossier3.reload.groupe_instructeur.label).to eq 'défaut'
      expect(dossier3.dossier_assignment).to be_nil
      expect(procedure.reload.routing_alert).to be_falsey
    end
  end
end
