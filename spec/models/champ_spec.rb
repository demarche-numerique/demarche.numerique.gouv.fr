# frozen_string_literal: true

describe Champ do
  include ActiveJob::TestHelper

  describe 'mandatory_blank?' do
    let(:type_de_champ) { build(:type_de_champ, mandatory: mandatory) }
    let(:champ) { Champs::TextChamp.new(value: value) }
    let(:value) { '' }
    let(:mandatory) { true }

    context 'with champ' do
      before { allow(champ).to receive(:type_de_champ).and_return(type_de_champ) }

      context 'when mandatory and blank' do
        it { expect(champ.mandatory_blank?).to be(true) }
      end

      context 'when carte mandatory and blank' do
        let(:type_de_champ) { build(:type_de_champ_carte, mandatory: mandatory) }
        let(:champ) { Champs::CarteChamp.new(value: value) }
        let(:value) { nil }
        it { expect(champ.mandatory_blank?).to be(true) }
      end

      context 'when multiple_drop_down_list mandatory and blank' do
        let(:type_de_champ) { build(:type_de_champ_multiple_drop_down_list, mandatory: mandatory) }
        let(:champ) { Champs::MultipleDropDownListChamp.new(value: value) }
        let(:value) { '[]' }
        it { expect(champ.mandatory_blank?).to be(true) }
      end

      context 'when repetition blank' do
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, mandatory: false, children: [{ type: :text }] }]) }
        let(:dossier) { create(:dossier, procedure:) }
        let(:champ) { dossier.project_champs_public.find(&:repetition?) }

        it { expect(champ.blank?).to be(true) }
      end

      context 'when not blank' do
        let(:value) { 'yop' }
        it { expect(champ.mandatory_blank?).to be(false) }
      end

      context 'when not mandatory' do
        let(:mandatory) { false }
        it { expect(champ.mandatory_blank?).to be(false) }
      end

      context 'when not mandatory or blank' do
        let(:value) { 'u' }
        let(:mandatory) { false }
        it { expect(champ.mandatory_blank?).to be(false) }
      end
    end

    context 'when repetition not blank' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, children: [{ type: :text }] }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:champ) { dossier.project_champs_public.find(&:repetition?) }

      it { expect(champ.blank?).to be(false) }
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:dossier) }
  end

  describe "normalization" do
    it "should remove null bytes char using unicode escape sequence" do
      champ = Champ.new(value: "foo\u0000bar")
      champ.validate
      expect(champ.value).to eq "foobar"
    end

    it 'removes remove null bytes char hexadecimal escape sequence' do
      champ = Champ.new(value: "Valid\x00Value")
      champ.validate
      expect(champ.value).to eq("ValidValue")
    end
  end

  describe 'public and private' do
    let(:champ) { Champ.new }
    let(:dossier) { create(:dossier) }

    it 'partition public and private' do
      expect(dossier.project_champs_public.count).to eq(1)
      expect(dossier.project_champs_private.count).to eq(1)
    end

    it do
      expect(champ.public?).to be_truthy
      expect(champ.private?).to be_falsey
    end

    context 'when a procedure has 2 revisions' do
      it { expect(dossier.procedure.revisions.count).to eq(2) }

      it 'does not duplicate public champs' do
        expect(dossier.project_champs_public.count).to eq(1)
      end

      it 'does not duplicate private champs' do
        expect(dossier.project_champs_private.count).to eq(1)
      end
    end
  end

  describe '#sections' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{}, { type: :header_section }, { type: :repetition, mandatory: true, children: [{ type: :header_section }] }], types_de_champ_private: [{}, { type: :header_section }])
    end
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:public_champ) { dossier.project_champs_public.first }
    let(:private_champ) { dossier.project_champs_private.first }
    let(:standalone_champ) { build(:champ, type_de_champ: build(:type_de_champ), dossier: build(:dossier)) }
    let(:public_sections) { dossier.project_champs_public.filter(&:header_section?) }
    let(:private_sections) { dossier.project_champs_private.filter(&:header_section?) }
    let(:sections_in_repetition) { dossier.project_champs_public.find(&:repetition?).rows.flatten.filter(&:header_section?) }

    it 'returns the sibling sections of a champ' do
      expect(public_sections).not_to be_empty
      expect(private_sections).not_to be_empty
      expect(sections_in_repetition).not_to be_empty
    end
  end

  describe '#format_datetime' do
    let(:champ) { Champs::DatetimeChamp.new(value: value) }
    before { champ.run_callbacks(:validation) }
    context 'when the value is sent by a modern browser' do
      let(:value) { '2017-12-31 10:23' }

      it { expect(champ.value).to eq(Time.zone.parse("2017-12-31T10:23:00").iso8601) }
    end

    context 'when the value is sent by a old browser' do
      let(:value) { '31/12/2018 09:26' }

      it { expect(champ.value).to eq(Time.zone.parse("2018-12-31T09:26:00").iso8601) }
    end
  end

  describe '#multiple_select_to_string' do
    let(:champ) { Champs::MultipleDropDownListChamp.new(value: value) }
    # before { champ.save! }

    # when using the old form, and the ChampsService Class
    # TODO: to remove
    context 'when the value is already deserialized' do
      let(:value) { '["val1","val2"]' }

      it { expect(champ.value).to eq(value) }

      context 'when the value is nil' do
        let(:value) { nil }

        it { expect(champ.value).to eq(value) }
      end
    end

    # for explanation for the "" entry, see
    # https://apidock.com/rails/ActionView/Helpers/FormOptionsHelper/select
    # GOTCHA
    context 'when the value is not already deserialized' do
      context 'when a choice is selected' do
        let(:value) { '["", "val1", "val2"]' }

        it { expect(champ.value).to eq('["val1","val2"]') }
      end

      context 'when all choices are removed' do
        let(:value) { '[""]' }

        it { expect(champ.value).to eq(nil) }
      end
    end
  end

  describe 'for_export' do
    let(:champ) { Champs::TextChamp.new(value:, dossier: build(:dossier)) }
    before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_text)) }

    let(:value_for_export) { champ.type_de_champ.champ_value_for_export(champ) }

    context 'when type_de_champ is text' do
      let(:value) { '123' }

      it { expect(value_for_export).to eq('123') }
    end

    context 'when type_de_champ is textarea' do
      let(:champ) { Champs::TextareaChamp.new(value:, dossier: build(:dossier)) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_textarea)) }

      let(:value) { '<b>gras</b>' }

      it { expect(value_for_export).to eq('<b>gras</b>') }
    end

    context 'when type_de_champ is yes_no' do
      let(:champ) { Champs::YesNoChamp.new(value: value) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_yes_no)) }

      context 'if yes' do
        let(:value) { 'true' }

        it { expect(value_for_export).to eq('Oui') }
      end

      context 'if no' do
        let(:value) { 'false' }

        it { expect(value_for_export).to eq('Non') }
      end

      context 'if nil' do
        let(:value) { nil }

        it { expect(value_for_export).to eq('') }
      end
    end

    context 'when type_de_champ is multiple_drop_down_list' do
      let(:champ) { Champs::MultipleDropDownListChamp.new(value:, dossier: build(:dossier)) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_multiple_drop_down_list, drop_down_options: ["Crétinier", "Mousserie"])) }

      let(:value) { '["Crétinier", "Mousserie"]' }

      it { expect(value_for_export).to eq('Crétinier, Mousserie') }
    end

    context 'when type_de_champ and champ.type mismatch' do
      let(:value) { :noop }
      let(:champ_iban) { Champs::IbanChamp.new(value: 'FR1234') }
      let(:champ_text) { Champs::TextChamp.new(value: 'hello') }
      let(:type_de_champ_iban) { build(:type_de_champ_iban) }
      let(:type_de_champ_text) { build(:type_de_champ_text) }
      before do
        allow(champ_iban).to receive(:type_de_champ).and_return(type_de_champ_iban)
        allow(champ_text).to receive(:type_de_champ).and_return(type_de_champ_text)
      end

      it do
        expect(type_de_champ_text.champ_value_for_export(champ_iban)).to eq(nil)
        expect(type_de_champ_iban.champ_value_for_export(champ_text)).to eq(nil)
      end
    end
  end

  describe '#search_terms' do
    subject { champ.search_terms }

    context 'for adresse champ' do
      let(:champ) { Champs::AddressChamp.new(value:, not_in_ban: 'true', street_address: '10 rue du Pinson qui Piaille', city_name: 'Piaille', postal_code: '1234', country_code: 'IT') }
      let(:value) { "10 rue du Pinson qui Piaille" }

      it { is_expected.to eq([value, 'Piaille']) }
    end

    context 'for checkbox champ' do
      let(:libelle) { champ.libelle }
      let(:champ) { Champs::CheckboxChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_checkbox)) }
      context 'when the box is checked' do
        let(:value) { 'true' }

        it { is_expected.to eq([libelle]) }
      end

      context 'when the box is unchecked' do
        let(:value) { 'false' }

        it { is_expected.to be_nil }
      end
    end

    context 'for civilite champ' do
      let(:champ) { Champs::CiviliteChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_civilite)) }
      let(:value) { "M." }

      it { is_expected.to eq([value]) }
    end

    context 'for date champ' do
      let(:champ) { Champs::DateChamp.new(value:) }
      let(:value) { "2018-07-30" }

      it { is_expected.to be_nil }
    end

    context 'for date time champ' do
      let(:champ) { Champs::DatetimeChamp.new(value:) }
      let(:value) { "2018-04-29 09:00" }

      it { is_expected.to be_nil }
    end

    context 'for département champ' do
      let(:champ) { Champs::DepartementChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_departements)) }
      let(:value) { "69" }

      it { is_expected.to eq(['69 – Rhône']) }
    end

    context 'for dossier link champ' do
      let(:champ) { Champs::DossierLinkChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_dossier_link)) }
      let(:value) { "9103132886" }

      it { is_expected.to eq([value]) }
    end

    context 'for drop down list champ' do
      let(:champ) { Champs::DropDownListChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_drop_down_list)) }
      let(:value) { "val1" }

      it { is_expected.to eq([value]) }
    end

    context 'for email champ' do
      let(:champ) { Champs::EmailChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_email)) }
      let(:value) { "machin@example.com" }

      it { is_expected.to eq([value]) }
    end

    context 'for explication champ' do
      let(:champ) { Champs::ExplicationChamp.new }

      it { is_expected.to be_nil }
    end

    context 'for header section champ' do
      let(:champ) { Champs::HeaderSectionChamp.new }

      it { is_expected.to be_nil }
    end

    context 'for linked drop down list champ' do
      let(:champ) { Champs::LinkedDropDownListChamp.new(value: '["hello","world"]') }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_linked_drop_down_list, drop_down_options: ['--hello--', 'world'])) }

      it { is_expected.to eq(["hello", "world"]) }
    end

    context 'for multiple drop down list champ' do
      let(:champ) { Champs::MultipleDropDownListChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_multiple_drop_down_list, drop_down_options: ['goodbye', 'cruel', 'world'])) }

      context 'when there are multiple values selected' do
        let(:value) { JSON.generate(['goodbye', 'cruel', 'world']) }

        it { is_expected.to eq(["goodbye", "cruel", "world"]) }
      end

      context 'when there is no value selected' do
        let(:value) { nil }

        it { is_expected.to eq([]) }
      end
    end

    context 'for number champ' do
      let(:champ) { Champs::NumberChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_number)) }

      let(:value) { "1234" }

      it { is_expected.to eq([value]) }
    end

    context 'for pays champ' do
      let(:champ) { Champs::PaysChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_pays)) }

      let(:value) { "FR" }

      it { is_expected.to eq(['France']) }
    end

    context 'for phone champ' do
      let(:champ) { Champs::PhoneChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_phone)) }
      let(:value) { "06 06 06 06 06" }

      it { is_expected.to eq([value]) }
    end

    context 'for pièce justificative champ' do
      let(:champ) { Champs::PieceJustificativeChamp.new(value:) }
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context 'for region champ' do
      let(:champ) { Champs::RegionChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_regions)) }
      let(:value) { "11" }

      it { is_expected.to eq(['Île-de-France']) }
    end

    context 'for siret champ' do
      context 'when there is an etablissement' do
        let(:etablissement) do
          build(
            :etablissement,
            siret: "35130347400024",
            siege_social: true,
            naf: "9004Z",
            libelle_naf: "Gestion de salles de spectacles",
            adresse: "MAISON JEUNES CULTURE FABRIQUE\r\n98 RUE DE PARIS\r\n59200 TOURCOING\r\nFRANCE\r\n",
            numero_voie: "98",
            type_voie: "RUE",
            nom_voie: "DE PARIS",
            code_postal: "59200",
            localite: "TOURCOING",
            code_insee_localite: "59599",
            entreprise_siren: "351303474",
            entreprise_numero_tva_intracommunautaire: "FR02351303474",
            entreprise_forme_juridique: "Association déclarée ",
            entreprise_forme_juridique_code: "9220",
            entreprise_nom_commercial: "",
            entreprise_raison_sociale: "MAISON DES JEUNES ET DE LA CULTURE DE LA FABRIQUE",
            entreprise_siret_siege_social: "35130347400024",
            entreprise_nom: 'Martin',
            entreprise_prenom: 'Guillaume',
            entreprise_code_effectif_entreprise: "12",
            entreprise_date_creation: "1989-07-09",
            association_rna: "W595004053",
            association_titre: "MAISON DES JEUNES ET DE LA CULTURE DE LA FABRIQUE",
            association_objet: "Création, gestion et animation de la Maison des Jeunes et de la Culture de la Fabrique, qui constitue un élément essentiel de la vie sociale et culturelle d’un territoire de vie : pays, agglomération, ville, communauté de communes, village, quartier ...",
            association_date_creation: "1962-05-23",
            association_date_declaration: "2016-12-02",
            association_date_publication: "1962-05-31"
          )
        end
        let(:champ) { Champs::SiretChamp.new(value: etablissement.siret, etablissement:) }

        it { is_expected.to eq([etablissement.entreprise_siren, etablissement.entreprise_numero_tva_intracommunautaire, etablissement.entreprise_forme_juridique, etablissement.entreprise_forme_juridique_code, etablissement.entreprise_nom_commercial, etablissement.entreprise_raison_sociale, etablissement.entreprise_siret_siege_social, etablissement.entreprise_nom, etablissement.entreprise_prenom, etablissement.association_rna, etablissement.association_titre, etablissement.association_objet, etablissement.siret, etablissement.enseigne, etablissement.naf, etablissement.libelle_naf, etablissement.adresse, etablissement.code_postal, etablissement.localite, etablissement.code_insee_localite, nil]) }
      end

      context 'when there is no etablissement' do
        let(:champ) { Champs::SiretChamp.new(value:, etablissement: nil) }
        let(:value) { "35130347400024" }

        it { is_expected.to eq([value]) }
      end
    end

    context 'for text champ' do
      let(:champ) { Champs::TextChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_text)) }
      let(:value) { "Blah" }

      it { is_expected.to eq([value]) }
    end

    context 'for text area champ' do
      let(:champ) { Champs::TextareaChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_textarea)) }
      let(:value) { "Bla\nBlah de bla." }

      it { is_expected.to eq([value]) }
    end

    context 'for yes/no champ' do
      let(:champ) { Champs::YesNoChamp.new(value:) }
      before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_yes_no)) }

      let(:libelle) { champ.libelle }

      context 'when the box is checked' do
        let(:value) { "true" }

        it { is_expected.to eq([libelle]) }
      end

      context 'when the box is unchecked' do
        let(:value) { "false" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#enqueue_virus_scan' do
    context 'when type_champ is type_de_champ_piece_justificative' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champs.first }

      context 'and there is a blob' do
        before do
          allow(ClamavService).to receive(:safe_file?).and_return(true)
        end

        subject do
          champ.piece_justificative_file.attach(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
          champ.save!
          champ
        end

        it 'marks the file as pending virus scan' do
          expect(subject.piece_justificative_file.first.virus_scanner.started?).to be_truthy
        end

        it 'marks the file as safe once the scan completes' do
          subject
          perform_enqueued_jobs
          expect(champ.reload.piece_justificative_file.first.virus_scanner.safe?).to be_truthy
        end
      end
    end
  end

  describe '#enqueue_watermark_job' do
    context 'when type_champ is type_de_champ_titre_identite' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :titre_identite }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champs.first }

      before do
        allow(ClamavService).to receive(:safe_file?).and_return(true)
      end

      subject do
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
        champ.save!
        champ
      end

      it 'marks the file as needing watermarking' do
        expect(subject.piece_justificative_file.first.watermark_pending?).to be_truthy
      end

      it 'watermarks the file', :external_deps do
        subject
        perform_enqueued_jobs
        expect(champ.reload.piece_justificative_file.first.watermark_pending?).to be_falsy
        expect(champ.reload.piece_justificative_file.first.blob.watermark_done?).to be_truthy
      end
    end
  end

  describe "#input_name" do
    let(:champ) { Champs::TextChamp.new }
    it { expect(champ.input_name).to eq "dossier[champs_public_attributes][#{champ.public_id}]" }

    context "when private" do
      let(:champ) { Champs::TextChamp.new(private: true) }
      it { expect(champ.input_name).to eq "dossier[champs_private_attributes][#{champ.public_id}]" }
    end
  end

  describe 'dom_id' do
    let(:champ) { Champs::TextChamp.new(row_id: '1234') }
    before do
      allow(champ).to receive(:type_de_champ).and_return(create(:type_de_champ_text))
    end

    it do
      expect(champ.public_id).to eq("#{champ.stable_id}-#{champ.row_id}")
      expect(ActionView::RecordIdentifier.dom_id(champ)).to eq("champ_#{champ.public_id}")
      expect(ActionView::RecordIdentifier.dom_id(champ.type_de_champ)).to eq("type_de_champ_#{champ.type_de_champ.id}")
      expect(ActionView::RecordIdentifier.dom_class(champ)).to eq("champ")
    end
  end

  describe 'clone' do
    let(:procedure) { create(:procedure, types_de_champ_private:, types_de_champ_public:) }
    let(:types_de_champ_private) { [] }
    let(:types_de_champ_public) { [] }
    let(:champ) { dossier.champs.first }

    subject { champ.clone }

    context 'when champ referentiel' do
      let(:referentiel) { create(:api_referentiel, :autocomplete) }
      let(:types_de_champ_public) { [{ type: :referentiel, referentiel:, mandatory: true }] }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

      context 'when referentiel' do
        let(:data) { { 'id' => '123', 'label' => 'foo' } }
        before { champ.update_columns(data:) }
        it { expect(subject.data).to eq(data) }
      end
    end

    context 'when champ public' do
      let(:types_de_champ_public) { [{ type: :piece_justificative }] }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

      it { expect(subject.piece_justificative_file).to be_attached }
    end

    context 'champ private' do
      let(:dossier) { create(:dossier, :with_populated_annotations, procedure:) }
      let(:types_de_champ_private) { [{ type: :piece_justificative }] }

      it { expect(subject.piece_justificative_file).not_to be_attached }
    end
  end

  describe "#parent" do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, mandatory: false, children: [{ type: :text }] }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }

    let(:champ) { dossier.champs.where(type: "Champs::TextChamp").first }

    it "returns the parent" do
      expect(champ.parent).to eq(TypeDeChamp.find_by(type_champ: "repetition"))
    end
  end
end
