# frozen_string_literal: true

RSpec.describe DossierSubmittedMessage do
  describe '#tiptap_body_or_default' do
    context 'when json_body is present' do
      let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "From TipTap" }] }] } }
      let(:dsm) { build(:dossier_submitted_message, json_body:, message_on_submit_by_usager: "Legacy text") }

      it 'returns json_body as JSON string' do
        expect(dsm.tiptap_body_or_default).to eq(json_body.to_json)
      end
    end

    context 'when json_body is nil but message_on_submit_by_usager is present' do
      let(:dsm) { build(:dossier_submitted_message, json_body: nil, message_on_submit_by_usager: "Hello world") }

      it 'converts message_on_submit_by_usager to tiptap JSON' do
        result = JSON.parse(dsm.tiptap_body_or_default)
        expect(result["type"]).to eq("doc")
        expect(result["content"].first["type"]).to eq("paragraph")
        expect(result["content"].first["content"].first["text"]).to eq("Hello world")
      end
    end

    context 'when both json_body and message_on_submit_by_usager are empty' do
      let(:dsm) { build(:dossier_submitted_message, json_body: nil, message_on_submit_by_usager: nil) }

      it 'returns default empty tiptap JSON' do
        result = JSON.parse(dsm.tiptap_body_or_default)
        expect(result["type"]).to eq("doc")
        expect(result["content"]).to eq([{ "type" => "paragraph" }])
      end
    end

    context 'with multiple paragraphs in legacy text' do
      let(:dsm) { build(:dossier_submitted_message, json_body: nil, message_on_submit_by_usager: "First paragraph\n\nSecond paragraph") }

      it 'converts each paragraph separately' do
        result = JSON.parse(dsm.tiptap_body_or_default)
        expect(result["content"].length).to eq(2)
        expect(result["content"][0]["content"].first["text"]).to eq("First paragraph")
        expect(result["content"][1]["content"].first["text"]).to eq("Second paragraph")
      end
    end
  end

  describe '#body_as_html' do
    context 'when json_body is present' do
      let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Hello" }] }] } }
      let(:dsm) { build(:dossier_submitted_message, json_body:) }

      it 'returns HTML from TiptapService' do
        expect(dsm.body_as_html).to include('<p')
        expect(dsm.body_as_html).to include('Hello')
      end
    end

    context 'when json_body is nil' do
      let(:dsm) { build(:dossier_submitted_message, json_body: nil) }

      it 'returns nil' do
        expect(dsm.body_as_html).to be_nil
      end
    end
  end

  describe '#body_as_text' do
    subject { build(:dossier_submitted_message, json_body:, message_on_submit_by_usager: "Ancien texte").body_as_text }

    context 'when json_body is present' do
      let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Merci pour votre dépôt." }] }] } }

      it { is_expected.to eq("Merci pour votre dépôt.") }
    end

    context 'when json_body is nil' do
      let(:json_body) { nil }

      it { is_expected.to be_nil }
    end
  end
end
