# frozen_string_literal: true

describe ExportTemplate do
  let(:groupe_instructeur) { create(:groupe_instructeur, procedure:) }
  let(:export_template) { build(:export_template, kind: 'csv', groupe_instructeur:) }
  let(:tabular_export_template) { build(:tabular_export_template, groupe_instructeur:) }
  let(:procedure) { create(:procedure_with_dossiers, :published, types_de_champ_public:, for_individual:) }
  let(:for_individual) { true }
  let(:types_de_champ_public) do
    [
      { type: :text, libelle: "Ca va ?", mandatory: true, stable_id: 1 },
      { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
      { type: :siret, libelle: 'siret', stable_id: 20 },
      { type: :repetition, mandatory: true, stable_id: 7, libelle: "Champ répétable", children: [{ type: 'text', libelle: 'Qqchose à rajouter?', stable_id: 8 }] },
    ]
  end

  describe '#exported_columns=' do
    it 'is assignable/readable with ExportedColumn object' do
      expect do
        export_template.exported_columns = [
          ExportedColumn.new(libelle: 'Ça va ?', column: procedure.find_column(label: "Ca va ?")),
        ]
        export_template.save!
        export_template.exported_columns
      end.not_to raise_error
    end
    it 'create exported_column' do
      export_template.exported_columns = [
        ExportedColumn.new(libelle: 'Ça va ?', column: procedure.find_column(label: "Ca va ?")),
      ]
      export_template.save!
      expect(export_template.exported_columns.size).to eq 1
    end

    context 'when there is a previous revision with a renamed tdc' do
      context 'with already column in export template' do
        let(:previous_tdc) { procedure.published_revision.types_de_champ_public.find { _1.stable_id == 1 } }
        let(:changed_tdc) { { libelle: "Ca roule ?" } }

        context 'with already column in export template' do
          before do
            export_template.exported_columns = [
              ExportedColumn.new(libelle: 'Ça va ?', column: procedure.find_column(label: "Ca va ?")),
            ]
            export_template.save!

            type_de_champ = procedure.draft_revision.find_and_ensure_exclusive_use(previous_tdc.stable_id)
            type_de_champ.update(changed_tdc)
            procedure.publish_revision!(procedure.administrateurs.first)
          end

          it 'update columns with original libelle for champs with new revision' do
            Current.procedure_columns = {}
            procedure.reload
            export_template.reload
            expect(export_template.exported_columns.find { _1.column.stable_id.to_s == "1" }.libelle).to eq('Ça va ?')
          end
        end
      end
      context 'without columns in export template' do
        let(:previous_tdc) { procedure.published_revision.types_de_champ_public.find { _1.stable_id == 1 } }
        let(:changed_tdc) { { libelle: "Ca roule ?" } }

        before do
          type_de_champ = procedure.draft_revision.find_and_ensure_exclusive_use(previous_tdc.stable_id)
          type_de_champ.update(changed_tdc)
          procedure.publish_revision!(procedure.administrateurs.first)

          export_template.exported_columns = [
            ExportedColumn.new(libelle: 'Ça roule ?', column: procedure.find_column(label: "Ca roule ?")),
          ]
          export_template.save!
        end

        it 'update columns with original libelle for champs with new revision' do
          Current.procedure_columns = {}
          procedure.reload
          export_template.reload
          expect(export_template.exported_columns.find { _1.column.stable_id.to_s == "1" }.libelle).to eq('Ça roule ?')
        end
      end
    end
  end

  describe 'exported_columns with a stale column reference' do
    it 'filters out columns that no longer exist in the procedure' do
      export_template.exported_columns = [
        ExportedColumn.new(libelle: 'Ça va ?', column: procedure.find_column(label: "Ca va ?")),
      ]
      export_template.save!

      # Inject a stale column reference directly in the DB (simulates a TDC removed on a test procedure after template was saved)
      stale_entry = JSON.generate(id: { procedure_id: procedure.id, column_id: "type_de_champ/580046" }, libelle: "Removed field")
      valid_entry = ExportedColumnType.new.serialize(export_template.exported_columns.first)

      ExportTemplate.where(id: export_template.id)
        .update_all(Arel.sql("exported_columns = ARRAY[#{ActiveRecord::Base.connection.quote(valid_entry)}::jsonb, #{ActiveRecord::Base.connection.quote(stale_entry)}::jsonb]"))

      Current.procedure_columns = {}
      reloaded = ExportTemplate.find(export_template.id)
      expect { reloaded.exported_columns }.not_to raise_error
      expect(reloaded.exported_columns.size).to eq(1)
      expect(reloaded.exported_columns.first.libelle).to eq('Ça va ?')
    end
  end

  describe 'dossier_exported_columns' do
    context 'when exported_columns is empty' do
      it 'returns an empty array' do
        expect(export_template.dossier_exported_columns).to eq([])
      end
    end

    context 'when exported_columns is not empty' do
      before do
        export_template.exported_columns = [
          ExportedColumn.new(libelle: 'Colonne usager', column: procedure.find_column(label: "Adresse électronique")),
          ExportedColumn.new(libelle: 'Ça va ?', column: procedure.find_column(label: "Ca va ?")),
        ]
      end
      it 'returns all columns except tdc columns' do
        expect(export_template.dossier_exported_columns.size).to eq(1) # exclude tdc
        expect(export_template.dossier_exported_columns.first.libelle).to eq("Colonne usager")
      end
    end
  end

  describe 'columns_for_stable_id' do
    before do
      export_template.exported_columns = procedure.published_revision.types_de_champ.first.columns(procedure: procedure).map do |column|
        ExportedColumn.new(libelle: column.label, column:)
      end
    end
    context 'when procedure has a TypeDeChamp::Commune' do
      let(:types_de_champ_public) do
        [
          { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
        ]
      end
      it 'is able to resolve stable_id' do
        expect(export_template.columns_for_stable_id(17).size).to eq(3)
      end
    end
    context 'when procedure has a TypeDeChamp::Siret' do
      let(:types_de_champ_public) do
        [
          { type: :siret, libelle: 'SIRET', stable_id: 20 },
        ]
      end
      it 'is able to resolve stable_id' do
        columns = export_template.columns_for_stable_id(20)

        expect(columns.find { _1.libelle == "SIRET" }).to be_present

        %w[
          $.entreprise_nom_commercial
          $.entreprise_raison_sociale
        ].each do |jsonpath|
          expect(columns.find { _1.column.respond_to?(:jsonpath) && _1.column.jsonpath == jsonpath }).to be_present
        end
      end
    end
    context 'when procedure has a TypeDeChamp::Text' do
      let(:types_de_champ_public) do
        [
          { type: :text, libelle: "Text", mandatory: true, stable_id: 15 },
        ]
      end
      it 'is able to resolve stable_id' do
        expect(export_template.columns_for_stable_id(15).size).to eq(1)
      end
    end
  end
end
