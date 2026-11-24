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
      draft_only_tdc = procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'Ville')
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

  describe 'dossier link column' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }
    let(:column) { procedure.customizable_columns.first }

    it 'keeps the bare libelle once saved and reloaded, on the column the reviewer screens resolve' do
      personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
      Current.reset

      reloaded = DossiersListPersonnalisation.find(personnalisation.id).displayed_columns.sole

      expect(reloaded.label).to eq('Dossier lié')
      expect(reloaded.h_id).to eq(column.h_id)
      expect(procedure.find_column(h_id: column.h_id).label).to eq('Dossier lié – N° dossier')
    end

    context 'when the field is no longer offered in the current revision' do
      include Logic

      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :yes_no, libelle: 'Lié ?', stable_id: 1 }, { type: :dossier_link, libelle: 'Dossier lié' }]) }
      let(:column) { procedure.customizable_columns.find { it.label == 'Dossier lié' } }

      def reloaded_after(personnalisation)
        procedure.publish_revision!(procedure.administrateurs.first)
        Current.reset
        DossiersListPersonnalisation.find(personnalisation.id).displayed_columns.sole
      end

      it 'keeps the bare libelle when the field was removed' do
        personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
        procedure.draft_revision.remove_type_de_champ(column.stable_id)

        reloaded = reloaded_after(personnalisation)

        expect(reloaded.label).to eq('Dossier lié')
        expect(reloaded).to eq(procedure.find_column(h_id: column.h_id))
        expect(procedure.find_column(h_id: column.h_id).label).to eq('Dossier lié – N° dossier')
      end

      it 'keeps the bare libelle when the field got a condition' do
        personnalisation = create(:dossiers_list_personnalisation, procedure:, displayed_columns: [column])
        procedure.draft_revision.find_and_ensure_exclusive_use(column.stable_id).update!(condition: ds_eq(champ_value(1), constant(true)))

        reloaded = reloaded_after(personnalisation)

        expect(procedure.reload.customizable_columns.map(&:stable_id)).not_to include(column.stable_id)
        expect(reloaded.label).to eq('Dossier lié')
        expect(reloaded.h_id).to eq(column.h_id)
      end
    end
  end
end
