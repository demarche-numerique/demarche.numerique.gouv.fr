# frozen_string_literal: true

describe TypesDeChamp::DossierLinkTypeDeChamp do
  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:columns) { tdc.columns(procedure_id: procedure.id) }
    let(:canonical_column) { tdc.canonical_column(procedure_id: procedure.id) }

    it 'exposes the linked dossier number, submission date, procedure title and procedure agency columns' do
      expect(columns.map(&:label)).to eq([
        'Dossier lié',
        'Dossier lié – Date de dépôt du dossier',
        'Dossier lié – Intitulé de la démarche',
        'Dossier lié – Service porteur de la démarche',
      ])
      expect(columns.map(&:type)).to eq([:text, :date, :text, :text])
      expect(columns.map(&:displayable)).to eq([true, true, true, true])
      expect(columns.map(&:filterable)).to eq([true, true, true, false])
      expect(columns.first.h_id).to eq(canonical_column.h_id)
      expect(columns.third.suggestions?).to be(true)
    end

    context 'when the champ is in a repetition' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, libelle: 'Bloc', children: [{ type: :dossier_link, libelle: 'Dossier lié' }] }]) }

      it 'prefixes the labels with the repetition' do
        expect(procedure.columns.map(&:label)).to include(
          'Bloc – Dossier lié',
          'Bloc – Dossier lié – Date de dépôt du dossier',
          'Bloc – Dossier lié – Intitulé de la démarche',
          'Bloc – Dossier lié – Service porteur de la démarche'
        )
      end
    end
  end
end
