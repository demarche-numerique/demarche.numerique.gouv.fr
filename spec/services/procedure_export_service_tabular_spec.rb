# frozen_string_literal: true

require 'csv'

describe ProcedureExportService do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, types_de_champ_public:, for_individual:, ask_birthday: true, instructeurs: [instructeur]) }
  let(:service) { ProcedureExportService.new(procedure, procedure.dossiers, instructeur, export_template) }
  let(:for_individual) { true }
  let(:types_de_champ_public) do
    [
      { type: :text, libelle: "first champ", mandatory: true, stable_id: 1 },
      { type: :communes, libelle: "Commune", mandatory: true, stable_id: 17 },
      { type: :piece_justificative, libelle: "PJ", stable_id: 30 },
      {
        type: :repetition, mandatory: true, stable_id: 7, libelle: "Champ répétable", children:
        [
          { type: 'text', libelle: 'child first champ', stable_id: 8 },
          { type: 'text', libelle: 'child second champ', stable_id: 9 },
        ],
      },
    ]
  end
  let(:exported_columns) { [] }

  describe 'to_xlsx' do
    let(:kind) { 'xlsx' }
    let(:export_template) { create(:export_template, kind:, exported_columns:, groupe_instructeur: procedure.defaut_groupe_instructeur) }
    let(:dossiers_sheet) { subject.sheets.first }
    let(:etablissements_sheet) { subject.sheets.second }
    let(:avis_sheet) { subject.sheets.third }
    let(:repetition_sheet) { subject.sheets.fourth }

    subject do
      service
        .to_xlsx
        .open { |f|
          xlsx = SimpleXlsxReader.open(f.path)
          # Slurp all data at once for each sheet
          xlsx.sheets.each { |sheet| sheet.rows.slurp }
          xlsx
        }
    end

    describe 'sheets' do
      it 'should have a sheet for each record type' do
        expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis'])
      end
    end

    describe 'Dossiers sheet' do
      context 'with multiple columns' do
        let(:exported_columns) do
          [
            ExportedColumn.new(libelle: 'Date du dernier évènement', column: procedure.find_column(label: 'Date du dernier évènement')),
            ExportedColumn.new(libelle: 'Adresse électronique', column: procedure.find_column(label: 'Adresse électronique')),
            ExportedColumn.new(libelle: 'Groupe instructeur', column: procedure.find_column(label: 'Groupe instructeur')),
            ExportedColumn.new(libelle: 'État du dossier', column: procedure.dossier_state_column),
            ExportedColumn.new(libelle: 'first champ', column: procedure.find_column(label: 'first champ')),
            ExportedColumn.new(libelle: 'Commune', column: procedure.find_column(label: 'Commune')),
            ExportedColumn.new(libelle: 'PJ', column: procedure.find_column(label: 'PJ')),
          ]
        end

        let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure) }
        let(:selected_headers) { ["Adresse électronique", "first champ", "Commune", "Groupe instructeur", "Date du dernier évènement", "État du dossier", "PJ"] }

        it 'should have only headers from export template' do
          expect(dossiers_sheet.headers).to match_array(selected_headers)
        end

        it 'should have data' do
          expect(procedure.dossiers.count).to eq 1
          expect(dossiers_sheet.data.size).to eq 1

          expect(dossiers_sheet.data).to match_array([[anything, dossier.user_email_for_display, "défaut", "En instruction", "text", "Coye-la-Forêt", "toto.txt"]])
        end
      end

      context 'with multiple groupe instructeur' do
        let(:exported_columns) { [ExportedColumn.new(libelle: 'Groupe instructeur', column: procedure.find_column(label: 'Groupe instructeur'))] }
        let(:types_de_champ_public) { [] }

        before do
          create(:groupe_instructeur, label: '2', procedure:)
          create(:dossier, :en_instruction, procedure:)
        end

        it 'find groupe instructeur data' do
          expect(dossiers_sheet.headers).to include('Groupe instructeur')
          expect(dossiers_sheet.data[0][dossiers_sheet.headers.index('Groupe instructeur')]).to eq('défaut')
        end
      end

      context 'with multiple pjs' do
        let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: "PJ" }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'PJ', column: procedure.find_column(label: 'PJ'))] }
        before do
          dossier = create(:dossier, :en_instruction, :with_populated_champs, procedure:)
          dossier.filled_champs_public
            .find { _1.is_a? Champs::PieceJustificativeChamp }
            .piece_justificative_file
            .attach(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
        end
        it { expect(dossiers_sheet.data.last.last).to eq "toto.txt, toto.txt" }
      end

      context 'with TypeDeChamp::PieceJustificativeTypeDeChamp (titre_identite)' do
        let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: "Titre d'identité", nature: :titre_identite }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: "Titre d'identité – filled", column: procedure.find_column(label: "Titre d'identité – filled"))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq 'présent' }
      end

      context 'with TypeDeChamp::MutlipleDropDownListTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :multiple_drop_down_list, libelle: "multiple_drop_down_list", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'Date du dernier évènement', column: procedure.find_column(label: 'multiple_drop_down_list'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq "val1, val2" }
      end

      context 'with TypeDeChamp:YesNoTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :yes_no, libelle: "yes_no", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'yes_no', column: procedure.find_column(label: 'yes_no'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq true }
      end

      context 'with TypeDeChamp:CheckboxTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :checkbox, libelle: "checkbox", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'checkbox', column: procedure.find_column(label: 'checkbox'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq true }
      end

      context 'with TypeDeChamp:DecimalNumberTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :decimal_number, libelle: "decimal", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'decimal', column: procedure.find_column(label: 'decimal'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq 42.1 }
      end

      context 'with TypeDeChamp:IntegerNumberTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :integer_number, libelle: "integer", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'integer', column: procedure.find_column(label: 'integer'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq 42.0 }
      end

      context 'with TypesDeChamp::LinkedDropDownListTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :linked_drop_down_list, libelle: "linked_drop_down_list", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'linked_drop_down_list', column: procedure.find_column(label: 'linked_drop_down_list'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to eq "primary / secondary" }
      end

      context 'with TypesDeChamp::DateTimeTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :datetime, libelle: "datetime", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'datetime', column: procedure.find_column(label: 'datetime'))] }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        before { dossier }
        it do
          champ_value = Time.zone.parse(dossier.champs.first.value)
          offset = champ_value.utc_offset
          sheet_value = Time.zone.at(dossiers_sheet.data.last.last - offset.seconds)
          expect(sheet_value).to eq(champ_value.round)
        end
      end

      context 'with TypesDeChamp::TextAreaTypeDeChamp' do
        let(:types_de_champ_public) { [{ type: :textarea, libelle: "textarea", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'textarea', column: procedure.find_column(label: 'textarea'))] }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        before do
          dossier
            .filled_champs_public
            .first
            .update(value: "franco￾allemand")
        end
        it 'can be read with BOM content' do
          expect(dossiers_sheet.data.last.last).to eq "franco allemand"
        end
      end

      context 'with TypesDeChamp::Date' do
        let(:types_de_champ_public) { [{ type: :date, libelle: "date", mandatory: true }] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'date', column: procedure.find_column(label: 'date'))] }
        before { create(:dossier, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to be_an_instance_of(Date) }
      end

      context 'with DossierColumn as datetime' do
        let(:types_de_champ_public) { [] }
        let(:exported_columns) { [ExportedColumn.new(libelle: 'Date de passage en instruction', column: procedure.find_column(label: 'Date de passage en instruction'))] }
        before { create(:dossier, :en_instruction, :with_populated_champs, procedure:) }
        it { expect(dossiers_sheet.data.last.last).to be_an_instance_of(Time) }
      end
    end

    describe 'Etablissement sheet' do
      let(:types_de_champ_public) { [{ type: :siret, libelle: 'siret', stable_id: 40 }] }
      let(:exported_columns) do
        [
          ExportedColumn.new(libelle: "N° dossier", column: procedure.find_column(label: "N° dossier")),
          ExportedColumn.new(libelle: "Demandeur", column: procedure.find_column(label: "Demandeur")),
          ExportedColumn.new(libelle: "siret", column: procedure.find_column(label: "siret")),
        ]
      end
      let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
      let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_entreprise, procedure: procedure) }

      let(:dossier_etablissement) { etablissements_sheet.data[1] }
      let(:champ_etablissement) { etablissements_sheet.data[0] }

      it 'should have siret header in dossiers sheet' do
        expect(dossiers_sheet.headers).to include('siret')
      end

      it 'should have headers in etablissement sheet' do
        expect(etablissements_sheet.headers).to eq([
          "Dossier ID",
          "Champ",
          "Établissement SIRET",
          "Etablissement enseigne",
          "Établissement siège social",
          "Établissement NAF",
          "Établissement libellé NAF",
          "Établissement Adresse",
          "Établissement numero voie",
          "Établissement type voie",
          "Établissement nom voie",
          "Établissement complément adresse",
          "Établissement code postal",
          "Établissement localité",
          "Établissement code INSEE localité",
          "Entreprise SIREN",
          "Entreprise capital social",
          "Entreprise numero TVA intracommunautaire",
          "Entreprise forme juridique",
          "Entreprise forme juridique code",
          "Entreprise nom commercial",
          "Entreprise raison sociale",
          "Entreprise SIRET siège social",
          "Entreprise code effectif entreprise",
          "Entreprise date de création",
          "Entreprise état administratif",
          "Entreprise nom",
          "Entreprise prénom",
          "Association RNA",
          "Association titre",
          "Association objet",
          "Association date de création",
          "Association date de déclaration",
          "Association date de publication",
        ])
      end
    end

    describe 'Avis sheet' do
      let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure) }
      let!(:avis) { create(:avis, :with_answer, dossier: dossier) }

      it 'should have headers and data' do
        expect(avis_sheet.headers).to eq([
          "Dossier ID",
          "Introduction",
          "Réponse",
          "Question",
          "Réponse oui/non",
          "Créé le",
          "Répondu le",
          "Instructeur",
          "Expert",
        ])
        expect(avis_sheet.data.size).to eq(1)
      end
    end

    describe 'Repetitions sheet' do
      let(:exported_columns) do
        [
          ExportedColumn.new(libelle: "Champ répétable – child second champ", column: procedure.find_column(label: "Champ répétable – child second champ")),
        ]
      end
      let!(:dossiers) do
        [
          create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure),
          create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure),
        ]
      end

      describe 'sheets' do
        it 'should have a sheet for repetition' do
          expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis', '(7) Champ repetable'])
        end
      end

      it 'should have headers' do
        expect(repetition_sheet.headers).to eq([
          "Dossier ID", "Ligne", "Champ répétable – child second champ",
        ])
      end

      it 'should have data' do
        expect(repetition_sheet.data.size).to eq 4
      end
    end
  end
end
