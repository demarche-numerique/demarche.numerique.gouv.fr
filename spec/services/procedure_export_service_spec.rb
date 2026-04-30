# frozen_string_literal: true

require 'csv'

describe ProcedureExportService do
  include ZipHelpers

  let(:instructeur) { create(:instructeur) }
  let(:service) { ProcedureExportService.new(procedure, procedure.dossiers, instructeur, export_template) }
  let(:export_template) { nil }

  describe 'to_xlsx' do
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

    let(:dossiers_sheet) { subject.sheets.first }
    let(:etablissements_sheet) { subject.sheets.second }
    let(:avis_sheet) { subject.sheets.third }
    let(:repetition_sheet) { subject.sheets.fourth }

    describe 'sheets' do
      let(:procedure) { create(:procedure) }

      it 'should have a sheet for each record type' do
        expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis'])
      end
    end

    describe 'Dossiers sheet' do
      context 'with all data for individual' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_all_champs) }
        let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure) }

        # before do
        #   # change one tdc place to check if the header is ordered
        #   tdc_first = procedure.active_revision.revision_types_de_champ_public.first
        #   tdc_last = procedure.active_revision.revision_types_de_champ_public.last

        #   tdc_first.update(position: tdc_last.position + 1)
        #   procedure.reload
        # end

        let(:nominal_headers) do
          [
            "ID",
            "Email",
            "FranceConnect ?",
            "Civilité",
            "Nom",
            "Prénom",
            "Dépôt pour un tiers",
            "Nom du mandataire",
            "Prénom du mandataire",
            "À archiver",
            "État du dossier",
            "Dernière mise à jour le",
            "Dernière mise à jour du dossier le",
            "Déposé le",
            "Passé en instruction le",
            "Traité le",
            "Motivation de la décision",
            "Instructeurs",
            "textarea",
            "date",
            "datetime",
            "number",
            "decimal_number",
            "integer_number",
            "checkbox",
            "civilite",
            "email",
            "phone",
            "address",
            "simple_drop_down_list",
            "multiple_drop_down_list",
            "linked_drop_down_list",
            "communes",
            "communes (Code INSEE)",
            "communes (Département)",
            "departements",
            "departements (Code)",
            "regions",
            "regions (Code)",
            "pays",
            "pays (Code)",
            "dossier_link",
            "piece_justificative",
            "rna",
            "carte",
            "iban",
            "siret",
            "annuaire_education",
            "cnaf",
            "dgfip",
            "pole_emploi",
            "mesri",
            "text",
            "epci",
            "epci (Code)",
            "epci (Département)",
            "cojo",
            "formatted",
            "rnf",
            "rnf (Nom)",
            "rnf (Adresse)",
            "rnf (Code INSEE Ville)",
            "rnf (Département)",
            "engagement_juridique",
            "yes_no",
            "referentiel",
            "quotient_familial",
          ]
        end

        it 'should have data' do
          expect(dossiers_sheet.headers).to match_array(nominal_headers)

          expect(dossiers_sheet.data.size).to eq(1)
          expect(etablissements_sheet.data.size).to eq(1)

          # SimpleXlsxReader is transforming datetimes in utc... It is only used in test so we just hack around.
          offset = dossier.depose_at.utc_offset
          depose_at = Time.zone.at(dossiers_sheet.data[0][13] - offset.seconds)
          en_instruction_at = Time.zone.at(dossiers_sheet.data[0][14] - offset.seconds)
          expect(dossiers_sheet.data.first.size).to eq(nominal_headers.size)
          expect(depose_at).to eq(dossier.depose_at.round)
          expect(en_instruction_at).to eq(dossier.en_instruction_at.round)
        end
      end

      context 'with a birthdate' do
        let(:procedure) { create(:procedure, :published, :for_individual, ask_birthday: true) }
        let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }

        it 'find date de naissance' do
          expect(dossiers_sheet.headers).to include('Date de naissance')
          expect(dossiers_sheet.data[0][dossiers_sheet.headers.index('Date de naissance')]).to be_a(Date)
        end
      end

      context 'with a procedure routee' do
        let(:procedure) { create(:procedure, :published, :for_individual) }
        let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }
        before { create(:groupe_instructeur, label: '2', procedure:) }

        it 'find groupe instructeur data' do
          expect(dossiers_sheet.headers).to include('Groupe instructeur')
          expect(dossiers_sheet.data[0][dossiers_sheet.headers.index('Groupe instructeur')]).to eq('défaut')
        end
      end

      context 'with a dossier having multiple pjs' do
        let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
        let(:types_de_champ_public) { [{ type: :piece_justificative }] }
        let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure:) }
        let!(:dossier_2) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure:) }
        before do
          dossier_2.project_champs_public
            .find { _1.is_a? Champs::PieceJustificativeChamp }
            .piece_justificative_file
            .attach(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
        end
        it { expect(dossiers_sheet.data.first.size).to eq(19) } # default number of header when procedure has only one champ
      end

      context 'with procedure chorus' do
        before { expect_any_instance_of(Procedure).to receive(:chorusable?).and_return(true) }
        let(:procedure) { create(:procedure, :published, :for_individual, :filled_chorus) }
        let!(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

        it 'includes chorus headers' do
          expect(dossiers_sheet.headers).to include('Domaine Fonctionnel')
          expect(dossiers_sheet.headers).to include('Référentiel De Programmation')
          expect(dossiers_sheet.headers).to include('Centre De Coût')
        end
      end

      context 'with BOM input' do
        let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
        let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
        let(:types_de_champ_public) { [{ type: :text, libelle: 'text' }] }
        before { dossier.champs.first.update(value: user_input) }
        let(:user_input) { "franco￾allemand" }
        it 'can be read with BOM content' do
          expect(dossiers_sheet).not_to be_nil
          expect(dossiers_sheet.headers).to include('text')
          expect(dossiers_sheet.data[0][dossiers_sheet.headers.index('text')]).to eq("franco allemand")
        end
      end

      context 'with simili html input' do
        let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
        let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }
        let(:types_de_champ_public) { [{ type: :text, libelle: 'text' }] }
        before { dossier.champs.first.update(value: user_input) }
        let(:user_input) { "Notation <A B C is OK" }
        it 'is not escaped' do
          expect(dossiers_sheet).not_to be_nil
          expect(dossiers_sheet.headers).to include('text')
          expect(dossiers_sheet.data[0][dossiers_sheet.headers.index('text')]).to eq("Notation <A B C is OK")
        end
      end
    end

    describe 'Etablissement sheet' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
      let(:types_de_champ_public) { [{ type: :siret, libelle: 'siret' }] }
      let!(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_entreprise, procedure: procedure) }

      let(:dossier_etablissement) { etablissements_sheet.data[1] }
      let(:champ_etablissement) { etablissements_sheet.data[0] }

      let(:nominal_headers) do
        [
          "ID",
          "Email",
          "FranceConnect ?",
          "Entreprise raison sociale",
          "À archiver",
          "État du dossier",
          "Dernière mise à jour le",
          "Dernière mise à jour du dossier le",
          "Déposé le",
          "Passé en instruction le",
          "Traité le",
          "Motivation de la décision",
          "Instructeurs",
          'siret',
        ]
      end

      context 'as csv' do
        subject do
          ProcedureExportService.new(procedure, procedure.dossiers, instructeur, export_template)
            .to_csv
            .open { |f| CSV.read(f.path) }
        end

        let(:nominal_headers) do
          [
            "ID",
            "Email",
            "FranceConnect ?",
            "Établissement SIRET",
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
            "À archiver",
            "État du dossier",
            "Dernière mise à jour le",
            "Dernière mise à jour du dossier le",
            "Déposé le",
            "Passé en instruction le",
            "Traité le",
            "Motivation de la décision",
            "Instructeurs",
            'siret',
          ]
        end

        let(:dossiers_sheet_headers) { subject.first }

        it 'should have headers' do
          expect(dossiers_sheet_headers).to match_array(nominal_headers)
        end
      end

      it 'should have headers and data' do
        expect(dossiers_sheet.headers).to match_array(nominal_headers)

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

        expect(etablissements_sheet.data.size).to eq(2)
        expect(dossier_etablissement[1]).to eq("Dossier")
        expect(champ_etablissement[1]).to eq("siret")
      end
    end

    describe 'Avis sheet' do
      let(:procedure) { create(:procedure, :published, :for_individual) }
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
      before do
        # change one tdc place to check if the header is ordered
        tdc_first = procedure.active_revision.revision_types_de_champ_public.first
        tdc_last = procedure.active_revision.revision_types_de_champ_public.last

        tdc_first.update(position: tdc_last.position + 1)
        procedure.reload
      end

      let(:types_de_champ_public) { [{ type: :repetition, children: [{ libelle: 'Nom' }, { libelle: 'Age' }] }] }
      let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
      let!(:dossiers) do
        [
          create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure),
          create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure),
        ]
      end
      let(:champ_repetition) { dossiers.first.project_champs_public.find { |champ| champ.type_champ == 'repetition' } }

      it 'should have sheets' do
        expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis', champ_repetition.type_de_champ.libelle_for_export])
      end

      context 'with cloned procedure' do
        let(:other_parent) { create(:type_de_champ_repetition, stable_id: champ_repetition.stable_id) }

        before do
          create(:type_de_champ, parent: create(:procedure_revision_type_de_champ, type_de_champ: other_parent, revision: create(:procedure).active_revision, position: 0))
        end

        it 'should have headers' do
          expect(repetition_sheet.headers).to eq([
            "Dossier ID",
            "Ligne",
            "Nom",
            "Age",
          ])
        end
      end

      it 'should have data' do
        expect(repetition_sheet.data.size).to eq(4)
      end

      context 'with invalid characters' do
        before do
          champ_repetition.type_de_champ.update(libelle: 'A / B \ C *[]?')
        end

        it 'should have valid sheet name' do
          expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis', "(#{champ_repetition.type_de_champ.stable_id}) A - B - C"])
        end
      end

      context 'with long libelle composed of utf8 characteres' do
        before do
          procedure.active_revision.types_de_champ_public.each do |type_de_champ|
            type_de_champ.update!(libelle: "#{type_de_champ.id} - ?/[] ééé ééé ééééééé ééééééé éééééééé. ééé éé éééééééé éé ééé. ééééé éééééééé ééé ééé.")
          end
          procedure.active_revision.children_of(champ_repetition.type_de_champ).each do |type_de_champ|
            type_de_champ.update!(libelle: "#{type_de_champ.id} - Quam rem nam maiores numquam dolorem nesciunt. Cum et possimus et aut. Fugit voluptas qui qui.")
          end
        end

        it 'should have valid sheet name' do
          expect { subject }.not_to raise_error
        end
      end

      context 'with non unique labels' do
        let(:types_de_champ_public) { [{ type: :repetition, libelle: 'Une repetition', children: [{}] }, { type: :repetition, libelle: 'Une repetition', children: [{}] }] }
        let(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure:) }
        let(:type_de_champ_repetition) { dossier.revision.types_de_champ_public.first }
        let(:another_type_de_champ_repetition) { dossier.revision.types_de_champ_public.second }

        it 'should have sheets' do
          expect(subject.sheets.map(&:name)).to eq(['Dossiers', 'Etablissements', 'Avis', type_de_champ_repetition.libelle_for_export, another_type_de_champ_repetition.libelle_for_export])
        end
      end

      context 'with empty repetition' do
        before do
          dossiers.flat_map { |dossier| dossier.project_champs_public.filter(&:repetition?) }.each do |champ|
            Champ.where(row_id: champ.row_ids).destroy_all
          end
        end

        it 'should not have data' do
          expect(repetition_sheet).to be_nil
        end
      end
    end
  end

  describe 'to_zip' do
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'piece_justificative' }] }

    subject { service.to_zip }
    context 'without files' do
      it 'does not raises in_batches' do
        expect { subject }.not_to raise_error
      end

      it 'returns an empty blob' do
        expect(subject).to be_an_instance_of(ActiveStorage::Blob)
      end
    end

    describe 'generate_dossiers_export' do
      it 'include_infos_administration (so it includes avis, champs privés)' do
        expect(ActiveStorage::DownloadableFile).to receive(:create_list_from_dossiers).with(dossiers: anything, user_profile: instructeur, export_template:).and_return([])
        subject
      end

      context 'with export_template' do
        let!(:dossier) { create(:dossier, :accepte, :with_populated_champs, :with_individual, procedure: procedure) }
        let(:dossier_exports) { PiecesJustificativesService.new(user_profile: instructeur, export_template:).generate_dossiers_export(Dossier.where(id: dossier)) }
        let(:export_template) { create(:export_template, :enabled_pjs, groupe_instructeur: procedure.defaut_groupe_instructeur) }
        before do
          allow_any_instance_of(ActiveStorage::Attachment).to receive(:url).and_return("https://opengraph.githubassets.com/d0e7862b24d8026a3c03516d865b28151eb3859029c6c6c2e86605891fbdcd7a/socketry/async-io")
        end

        it 'returns a blob with custom filenames' do
          VCR.use_cassette('archive/new_file_to_get_200') do
            subject
            Tempfile.create(['archive', '.zip']) do |temp_file|
              temp_file.binmode
              subject.download { |chunk| temp_file.write(chunk) }
              temp_file.close

              base_fn = "export"
              structure = [
                "#{base_fn}/",
                "#{base_fn}/dossier-#{dossier.id}/",
                "#{base_fn}/dossier-#{dossier.id}/piece_justificative-#{dossier.id}-01.txt",
                "#{base_fn}/dossier-#{dossier.id}/export-#{dossier.id}.pdf",
              ]
              expect(read_zip_entries(temp_file.path)).to match_array(structure)
            end
          end
        end
      end

      context 'with files (and http calls)' do
        let!(:dossier) { create(:dossier, :accepte, :with_populated_champs, :with_individual, procedure: procedure) }
        let(:dossier_exports) { PiecesJustificativesService.new(user_profile: instructeur, export_template: nil).generate_dossiers_export(Dossier.where(id: dossier)) }
        before do
          allow_any_instance_of(ActiveStorage::Attachment).to receive(:url).and_return("https://opengraph.githubassets.com/d0e7862b24d8026a3c03516d865b28151eb3859029c6c6c2e86605891fbdcd7a/socketry/async-io")
        end

        it 'returns a blob with valid files' do
          VCR.use_cassette('archive/new_file_to_get_200') do
            subject

            Tempfile.create(['archive', '.zip']) do |temp_file|
              temp_file.binmode
              subject.download { |chunk| temp_file.write(chunk) }
              temp_file.close

              base_fn = 'export'
              structure = [
                "#{base_fn}/",
                "#{base_fn}/dossier-#{dossier.id}/",
                "#{base_fn}/dossier-#{dossier.id}/pieces_justificatives/",
                "#{base_fn}/dossier-#{dossier.id}/#{ActiveStorage::DownloadableFile.timestamped_filename(ActiveStorage::Attachment.where(record_type: "Champ").first)}",
                "#{base_fn}/dossier-#{dossier.id}/#{ActiveStorage::DownloadableFile.timestamped_filename(dossier_exports.first.first)}",
              ]
              expect(read_zip_entries(temp_file.path)).to match_array(structure)
            end
          end
        end
      end
    end
  end

  describe 'to_geo_json' do
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :carte }] }

    subject do
      service
        .to_geo_json
        .open { |f| JSON.parse(f.read) }
    end

    let(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_individual, procedure: procedure) }
    let(:champ_carte) { dossier.project_champs_public.find(&:carte?) }
    let(:properties) { subject['features'].first['properties'] }

    before do
      create(:geo_area, :polygon, champ: champ_carte)
    end

    it 'should have features' do
      expect(subject['features'].size).to eq(3)
      expect(properties['dossier_id']).to eq(dossier.id)
      expect(properties['champ_id']).to eq(champ_carte.stable_id)
      expect(properties['champ_label']).to eq(champ_carte.libelle)
    end
  end
end
