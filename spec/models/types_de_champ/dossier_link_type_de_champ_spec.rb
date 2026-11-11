# frozen_string_literal: true

describe TypesDeChamp::DossierLinkTypeDeChamp do
  describe '#columns' do
    let(:target) { create(:procedure, libelle: 'Démarche cible') }
    let(:tdc_options) { {} }
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié', **tdc_options }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:columns) { tdc.columns(procedure_id: procedure.id) }
    let(:procedure_column) { columns.third }
    let(:canonical_column) { tdc.canonical_column(procedure_id: procedure.id) }
    let(:customization_column) { tdc.customization_column(procedure_id: procedure.id) }

    it 'exposes the linked dossier number, submission date, procedure title and procedure agency columns' do
      expect(columns.map(&:label)).to eq([
        'Dossier lié – N° dossier',
        'Dossier lié – Date de dépôt du dossier',
        'Dossier lié – Intitulé de la démarche',
        'Dossier lié – Service porteur de la démarche',
      ])
      expect(columns.map(&:type)).to eq([:text, :date, :enum, :text])
      expect(columns.map(&:displayable)).to eq([true, true, true, true])
      expect(columns.map(&:filterable)).to eq([true, true, true, false])
      expect(columns.first).to be_a(Columns::DossierLinkNumberColumn)
      expect(columns.first.column_id).to eq("type_de_champ/#{tdc.stable_id}")
    end

    it 'keeps the bare libelle outside the reviewer lists, on the same column' do
      expect(canonical_column.label).to eq('Dossier lié')
      expect(customization_column.label).to eq('Dossier lié')
      expect(tdc.change_column(procedure_id: procedure.id).label).to eq('Dossier lié')
      expect(customization_column.h_id).to eq(columns.first.h_id)
      expect(canonical_column.h_id).to eq(columns.first.h_id)
    end

    it 'exposes a filterable and displayable enum column' do
      expect(procedure_column).to be_a(Columns::DossierLinkProcedureColumn)
      expect(procedure_column.type).to eq(:enum)
      expect(procedure_column.filterable).to be(true)
      expect(procedure_column.displayable).to be(true)
    end

    context 'when the champ is limited to some procedures' do
      let(:tdc_options) { { procedures_limit: true, dossier_link_procedure_ids: [target.id] } }

      it 'lists the configured procedures' do
        expect(procedure_column.options_for_select).to eq([[target.libelle, target.id.to_s]])
      end
    end

    context 'when the champ is not limited' do
      let(:observed) { create(:procedure, libelle: 'Démarche observée') }

      before do
        create(:dossier, :en_construction, procedure:).champ_data.first.update!(value: create(:dossier, :en_construction, procedure: observed).id)
      end

      context 'because the limit is enabled without any procedure' do
        let(:tdc_options) { { procedures_limit: true, dossier_link_procedure_ids: [] } }

        it 'lists the observed procedures' do
          expect(procedure_column.options_for_select).to eq([[observed.libelle, observed.id.to_s]])
        end
      end

      context 'because the limit is disabled' do
        let(:tdc_options) { { procedures_limit: false, dossier_link_procedure_ids: [target.id] } }

        it 'lists the observed procedures' do
          expect(procedure_column.options_for_select).to eq([[observed.libelle, observed.id.to_s]])
        end
      end
    end

    context 'when the champ is in a repetition' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, libelle: 'Bloc', children: [{ type: :dossier_link, libelle: 'Dossier lié' }] }]) }

      it 'prefixes the labels with the repetition' do
        expect(procedure.columns.map(&:label)).to include(
          'Bloc – Dossier lié – N° dossier',
          'Bloc – Dossier lié – Date de dépôt du dossier',
          'Bloc – Dossier lié – Intitulé de la démarche',
          'Bloc – Dossier lié – Service porteur de la démarche'
        )
      end
    end
  end
end
