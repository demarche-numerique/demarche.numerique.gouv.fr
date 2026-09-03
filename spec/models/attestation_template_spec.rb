# frozen_string_literal: true

describe AttestationTemplate, type: :model do
  describe 'validates footer length' do
    let(:attestation_template) { build(:attestation_template, footer: footer) }

    subject do
      attestation_template.validate
      attestation_template.errors.details
    end

    context 'when the footer is too long' do
      let(:footer) { 'a' * 191 }

      it { is_expected.to match({ footer: [{ error: :too_long, count: 190 }] }) }
    end
  end

  describe 'validates block tags placement (v2)' do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :repetition, libelle: 'Langages', children: [{ type: :text, libelle: 'nom' }] },
        { type: :text, libelle: 'Nom' },
      ])
    end
    let(:repetition_tag) { "tdc#{procedure.draft_revision.public_root_type_de_champs.find(&:repetition?).stable_id}" }
    let(:text_tag) { "tdc#{procedure.draft_revision.public_root_type_de_champs.find { !_1.repetition? }.stable_id}" }
    let(:attestation_template) { build(:attestation_template, :v2, procedure:, json_body:) }

    def mention(id, label) = { 'type' => 'mention', 'attrs' => { 'id' => id, 'label' => label } }
    def doc(*content) = { 'type' => 'doc', 'content' => content }

    context 'with a repetition tag in a paragraph' do
      let(:json_body) { doc({ 'type' => 'paragraph', 'content' => [mention(repetition_tag, 'Langages')] }) }

      it { expect(attestation_template).to be_valid }
    end

    context 'with a text tag in a heading' do
      let(:json_body) { doc({ 'type' => 'heading', 'attrs' => { 'level' => 2 }, 'content' => [mention(text_tag, 'Nom')] }) }

      it { expect(attestation_template).to be_valid }
    end

    context 'with a repetition tag in a heading' do
      let(:json_body) { doc({ 'type' => 'heading', 'attrs' => { 'level' => 2 }, 'content' => [mention(repetition_tag, 'Langages')] }) }

      it 'is invalid' do
        expect(attestation_template).not_to be_valid
        expect(attestation_template.errors.full_messages).to include(/contient la balise "Langages" dans un titre/)
      end
    end

    context 'with a repetition tag in the title' do
      let(:json_body) { doc({ 'type' => 'title', 'content' => [mention(repetition_tag, 'Langages')] }) }

      it { expect(attestation_template).not_to be_valid }
    end
  end

  describe 'dup' do
    let(:attestation_template) { create(:attestation_template, attributes) }
    subject { attestation_template.dup }

    context 'with an attestation without images' do
      let(:attributes) { attributes_for(:attestation_template) }

      it "works" do
        is_expected.to have_attributes(attributes)
        is_expected.to have_attributes(id: nil)
        expect(subject.logo.attached?).to be_falsey
      end
    end

    context 'with an attestation with images' do
      let(:attestation_template) { create(:attestation_template, :with_files) }

      it do
        expect(subject.logo.attachment).not_to eq(attestation_template.logo.attachment)
        expect(subject.logo.blob).to eq(attestation_template.logo.blob)
        expect(subject.logo.attached?).to be_truthy

        expect(subject.signature.attachment).not_to eq(attestation_template.signature.attachment)
        expect(subject.signature.blob).to eq(attestation_template.signature.blob)
        expect(subject.signature.attached?).to be_truthy
      end
    end
  end

  describe 'invalidate attestation if images attachments are not valid' do
    subject { build(:attestation_template, :with_gif_files) }

    context 'with an attestation which has gif files' do
      it { is_expected.not_to be_valid }
    end
  end

  describe 'generate_attestation_for' do
    let(:procedure) do
      create(:procedure,
        public_type_de_champs: type_de_champs,
        private_type_de_champs: private_type_de_champs,
        attestation_acceptation_template: attestation_template)
    end
    let(:etablissement) { create(:etablissement) }
    let(:type_de_champs) { [] }
    let(:private_type_de_champs) { [] }
    let(:dossier) { create(:dossier, :accepte, procedure:) }

    let(:type_de_champs) do
      [
        { libelle: 'libelleA' },
        { libelle: 'libelleB' },
      ]
    end

    before do
      dossier.root_champs_public
        .find { |champ| champ.libelle == 'libelleA' }
        .update(value: 'libelle1')

      dossier.root_champs_public
        .find { |champ| champ.libelle == 'libelleB' }
        .update(value: 'libelle2')
    end

    subject {
      attestation_template.generate_attestation_for(dossier)
      dossier.attestation
    }

    context 'attestation v1' do
      let(:template_title) { 'title --libelleA--' }
      let(:template_body) { 'body --libelleB--' }
      let(:attestation_template) do
        build(:attestation_template,
          title: template_title,
          body: template_body)
      end

      let(:view_args) do
        arguments = nil

        allow(ApplicationController).to receive(:render).and_wrap_original do |m, *args|
          arguments = args.first[:assigns]
          m.call(*args)
        end

        attestation_template.generate_attestation_for(dossier)

        arguments
      end

      it 'passes the correct parameters and generates an attestation' do
        expect(view_args[:attestation][:title]).to eq('title libelle1')
        expect(view_args[:attestation][:body]).to eq('body libelle2')
        expect(subject.title).to eq('title libelle1')
        expect(subject.pdf).to be_attached
      end

      context 'when a tag value contains a < character' do
        before do
          dossier.root_champs_public
            .find { |champ| champ.libelle == 'libelleB' }
            .update(value: 'age < 18')
        end

        it 'renders < literally in the PDF body, not as &lt;' do
          text_calls = []
          allow_any_instance_of(Prawn::Document).to receive(:text).and_wrap_original do |m, text, *args|
            text_calls << text
            m.call(text, *args)
          end

          attestation_template.generate_attestation_for(dossier)

          body_call = text_calls.find { _1.include?('age') }
          expect(body_call).to include('age < 18')
          expect(body_call).not_to include('&lt;')
        end
      end
    end

    context 'when dossier is not in accepte or refuse state' do
      let(:attestation_template) do
        build(:attestation_template, title: 'title', body: 'body')
      end
      let(:dossier) { create(:dossier, :sans_suite, procedure:) }

      it 'does not create an attestation' do
        expect {
          attestation_template.generate_attestation_for(dossier)
        }.not_to change { Attestation.count }

        expect(dossier.attestation).to be_nil
      end
    end

    context 'when the pdf upload fails' do
      let(:attestation_template) do
        build(:attestation_template, title: 'title', body: 'body')
      end

      before do
        allow(ActiveStorage::Blob.service).to receive(:upload).and_raise('503 Service Unavailable')
      end

      it 'raises and does not persist the attestation nor its attachment' do
        expect { attestation_template.generate_attestation_for(dossier) }
          .to raise_error('503 Service Unavailable')
          .and not_change { Attestation.count }
          .and not_change { ActiveStorage::Attachment.count }

        expect(dossier.reload.attestation).to be_nil
      end
    end

    context 'attestation v2' do
      let(:attestation_template) do
        build(:attestation_template, :v2, :with_files, label_logo: "Ministère des specs")
      end

      before do
        stub_request(:post, WEASYPRINT_URL)
          .with(body: {
            html: /Ministère des specs.+Mon titre pour #{procedure.libelle}.+Dossier: n° #{dossier.id}/m,
            upstream_context: { procedure_id: procedure.id, dossier_id: dossier.id, pdf_variant: 'pdf/ua-1' },
          })
          .to_return(body: 'PDF_DATA')
      end

      it 'generates an attestation' do
        expect(subject.pdf).to be_attached
      end
    end
  end

  describe '#render_attributes_for' do
    context 'signature' do
      let(:dossier) { create(:dossier, procedure: attestation.procedure, groupe_instructeur: groupe_instructeur) }

      subject { attestation.render_attributes_for(dossier: dossier)[:signature] }

      context 'procedure with signature' do
        let(:attestation) { create(:attestation_template, signature: Rack::Test::UploadedFile.new('spec/fixtures/files/logo_test_procedure.png', 'image/png')) }

        context "groupe instructeur without signature" do
          let(:groupe_instructeur) { create(:groupe_instructeur, signature: nil) }

          it { expect(subject).to be_an_instance_of(ActiveStorage::Attached::One) }
        end

        context 'groupe instructeur with signature' do
          let(:groupe_instructeur) { create(:groupe_instructeur, signature: Rack::Test::UploadedFile.new('spec/fixtures/files/black.png', 'image/png')) }

          it { expect(subject).to be_an_instance_of(ActiveStorage::Attached::One) }
        end
      end

      context 'procedure without signature' do
        let(:attestation) { create(:attestation_template, signature: nil) }

        context "groupe instructeur without signature" do
          let(:groupe_instructeur) { create(:groupe_instructeur, signature: nil) }

          it { expect(subject.blob).to be_nil }
        end
      end
    end

    context 'body v2' do
      let(:procedure) { create(:procedure, :for_individual) }
      let(:attestation) do
        create(:attestation_template, :v2, procedure:, json_body: {
          "type" => "doc",
          "content" => [
            { "type" => "title", "attrs" => { "textAlign" => "center" }, "content" => [{ "text" => "Mon titre pour ", "type" => "text" }, { "type" => "mention", "attrs" => { "id" => "dossier_procedure_libelle", "label" => "libellé démarche" } }] },
            {
              "type" => "paragraph",
              "content" => [
                { "text" => "Nom: ", "type" => "text" },
                { "type" => "mention", "attrs" => { "id" => "individual_last_name", "label" => "nom" } },
                { "text" => " ", "type" => "text" },
                { "type" => "mention", "attrs" => { "id" => "individual_first_name", "label" => "prénom" } },
              ],
            },
          ],
        })
      end
      let(:dossier) { create(:dossier, procedure:, individual: build(:individual, nom: 'Doe', prenom: 'John')) }

      it do
        body = attestation.render_attributes_for(dossier: dossier)[:body]
        expect(body).to include("Mon titre pour #{dossier.procedure.libelle}")
        expect(body).to include("Doe John")
      end
    end
  end
end
