# frozen_string_literal: true

RSpec.describe DossiersListPersonnalisation, type: :model do
  describe 'uniqueness' do
    it 'forbids two personnalisations for the same user and procedure' do
      user = create(:user)
      procedure = create(:procedure)
      create(:dossiers_list_personnalisation, user:, procedure:)

      expect { create(:dossiers_list_personnalisation, user:, procedure:) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same user on a different procedure' do
      user = create(:user)
      create(:dossiers_list_personnalisation, user:, procedure: create(:procedure))

      expect { create(:dossiers_list_personnalisation, user:, procedure: create(:procedure)) }
        .not_to raise_error
    end
  end

  describe 'displayed_columns JSONB serialization' do
    it 'round-trips Column objects through the database' do
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }])
      column = procedure.columns.find { |c| c.is_a?(Columns::ChampColumn) }

      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
      personnalisation.reload

      expect(personnalisation.displayed_columns.map(&:id)).to eq([column.id])
    end

    it 'defaults to an empty array' do
      expect(create(:dossiers_list_personnalisation).displayed_columns).to eq([])
    end
  end

  describe 'stale displayed_columns' do
    it 'ignores a column that can no longer be resolved and keeps the others' do
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Pays' }])
      pays_column = procedure.customizable_columns.find { _1.label == 'Pays' }
      draft_only_tdc = procedure.draft_revision.add_type_de_champ(type: TypesDeChamp::Text.name, libelle: 'Ville')
      draft_only_column = draft_only_tdc.canonical_column(procedure_id: procedure.id)
      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [draft_only_column, pays_column])

      Current.reset

      displayed_columns = DossiersListPersonnalisation.find(personnalisation.id).displayed_columns
      expect(displayed_columns.map(&:label)).to eq(['Pays'])
    end

    it 'keeps a column whose champ was removed in a later published revision' do
      procedure = create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Ville' }, { type: :text, libelle: 'Pays' }])
      ville_column = procedure.customizable_columns.find { _1.label == 'Ville' }
      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [ville_column])

      procedure.draft_revision.remove_type_de_champ(ville_column.stable_id)
      procedure.publish_revision!(procedure.administrateurs.first)
      Current.reset

      displayed_columns = DossiersListPersonnalisation.find(personnalisation.id).displayed_columns
      expect(displayed_columns.map(&:label)).to eq(['Ville'])
    end
  end
end
