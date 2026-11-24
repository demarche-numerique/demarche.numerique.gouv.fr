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
      expect(columns.map(&:filterable)).to eq([true, false, true, false])
      expect(columns.first).to be_a(Columns::DossierLinkNumberColumn)
      base_id = "type_de_champ/#{tdc.stable_id}"
      expect(columns.map(&:column_id)).to eq([base_id, "#{base_id}-$.submitted_on", "#{base_id}-$.procedure_title", "#{base_id}-$.procedure_agency"])
      expect(columns.drop(1)).to all(have_attributes(usable_in_conditions?: false))
    end

    it 'keeps the bare libelle outside the reviewer lists, on the same column' do
      expect(canonical_column.label).to eq('Dossier lié')
      expect(customization_column.label).to eq('Dossier lié')
      expect(tdc.change_column(procedure_id: procedure.id).label).to eq('Dossier lié')
      expect(customization_column.h_id).to eq(columns.first.h_id)
      expect(canonical_column.h_id).to eq(columns.first.h_id)
    end

    context 'when the champ is limited to some procedures' do
      let(:tdc_options) { { procedures_limit: true, dossier_link_procedure_ids: [target.id] } }

      it 'lists the saved titles of submitted dossiers' do
        dossier = create(:dossier, :en_construction, procedure:)
        dossier.champ_data.first.update_columns(value_json: { procedure_title: 'Démarche observée' })

        expect(procedure_column.options_for_dossiers(Dossier.where(id: dossier.id))).to eq([['Démarche observée', 'Démarche observée']])
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
