# frozen_string_literal: true

require 'rails_helper'

describe Referentiels::APIReferentiel, type: :model do
  let(:authentication_data) { { "header" => 'Authorization', "value" => 'Bearer secret' } }
  it 'encrypts authentication_data' do
    referentiel = described_class.create!(name: SecureRandom.uuid, authentication_data:, mode: :autocomplete, url_tiptap: { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://api.gouv.fr/" }, { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Q" } }] }] }, test_data_tiptap: { "{query}" => "test" })

    referentiel.reload
    expect(referentiel.authentication_data).to eq(authentication_data)
    expect(Referentiel.where(id: referentiel.id).pluck(:authentication_data)).not_to include("Authorization")
  end

  describe '#tiptap_template=' do
    let(:referentiel) { build(:api_referentiel, :autocomplete) }

    it 'parses the serialized template' do
      referentiel.tiptap_template = { "type" => "doc" }.to_json
      expect(referentiel.json_template).to eq({ "type" => "doc" })
    end

    it 'empties the template instead of raising on a malformed payload' do
      expect { referentiel.tiptap_template = "not json" }.not_to raise_error
      expect(referentiel.json_template).to eq({})
    end
  end

  describe '#autocomplete_ready?' do
    let(:referentiel) { build(:api_referentiel, :autocomplete, datasource: '$.items') }

    it { expect(referentiel).to be_autocomplete_ready }

    it 'is false without a datasource' do
      referentiel.datasource = nil
      expect(referentiel).not_to be_autocomplete_ready
    end

    it 'is false without a rendering template' do
      referentiel.json_template = {}
      expect(referentiel).not_to be_autocomplete_ready
    end

    it 'is false for a csv referentiel' do
      expect(build(:csv_referentiel)).not_to be_autocomplete_ready
    end
  end

  describe '#tiptap_mention_stable_ids' do
    let(:referentiel) { build(:api_referentiel, :exact_match, url_tiptap:) }

    context 'when url_tiptap is nil' do
      let(:url_tiptap) { nil }
      it { expect(referentiel.tiptap_mention_stable_ids).to eq([]) }
    end

    context 'with one tdc mention' do
      let(:url_tiptap) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://api.gouv.fr/" }, { "type" => "mention", "attrs" => { "id" => "tdc42", "label" => "Dep" } }] }] } }
      it { expect(referentiel.tiptap_mention_stable_ids).to eq([42]) }
    end

    context 'with {query} and tdc mentions' do
      let(:url_tiptap) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } }, { "type" => "mention", "attrs" => { "id" => "tdc42", "label" => "Dep" } }, { "type" => "mention", "attrs" => { "id" => "tdc57", "label" => "Code" } }] }] } }
      it { expect(referentiel.tiptap_mention_stable_ids).to eq([42, 57]) }
    end
  end

  describe '#url_has_query_tag?' do
    let(:referentiel) { build(:api_referentiel, :exact_match, url_tiptap:) }

    context 'with {query} tag' do
      let(:url_tiptap) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } }] }] } }
      it { expect(referentiel.url_has_query_tag?).to be true }
    end

    context 'without {query} tag' do
      let(:url_tiptap) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "https://api.gouv.fr/" }] }] } }
      it { expect(referentiel.url_has_query_tag?).to be false }
    end

    context 'when url_tiptap is nil' do
      let(:url_tiptap) { nil }
      it { expect(referentiel.url_has_query_tag?).to be false }
    end
  end

  describe '#url_allowed?' do
    def tiptap_url(text)
      {
        "type" => "doc", "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => text },
              { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
            ],
          },
        ],
      }
    end

    context 'tiptap mode' do
      let(:referentiel) { build(:api_referentiel, :exact_match, url_tiptap:, test_data_tiptap: { "{query}" => "ok" }) }

      context 'with https gouv.fr URL' do
        let(:url_tiptap) { tiptap_url("https://data.gouv.fr/api?q=") }
        it { expect(referentiel).to be_valid }
      end

      context 'with https beta.gouv.fr URL in whitelist' do
        let(:url_tiptap) { tiptap_url("https://rnb-api.beta.gouv.fr/api?q=") }
        it { expect(referentiel).to be_valid }
      end

      context 'with http URL' do
        let(:url_tiptap) { tiptap_url("http://data.gouv.fr/api?q=") }

        it 'adds https_required error' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :https_required)).to be_present
        end
      end

      context 'with URL missing scheme' do
        let(:url_tiptap) { tiptap_url("data.gouv.fr/api?q=") }

        it 'adds https_required error' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :https_required)).to be_present
        end
      end

      context 'with non-whitelisted domain' do
        let(:url_tiptap) { tiptap_url("https://free.app/sample.json?id=") }

        it 'adds not_allowed error' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :not_allowed)).to be_present
        end

        it 'labels the attribute « URL du référentiel » in the full message' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :not_allowed).first.full_message).to include("URL du référentiel")
        end
      end

      context 'with only mentions and no text URL' do
        let(:url_tiptap) do
          {
            "type" => "doc", "content" => [
              {
                "type" => "paragraph", "content" => [
                  { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
                ],
              },
            ],
          }
        end

        it 'adds invalid_format error' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :invalid_format)).to be_present
        end
      end

      context 'with no mention tags' do
        let(:url_tiptap) do
          {
            "type" => "doc", "content" => [
              {
                "type" => "paragraph", "content" => [
                  { "type" => "text", "text" => "https://data.gouv.fr/api" },
                ],
              },
            ],
          }
        end

        it 'adds missing_query_params error' do
          referentiel.valid?
          expect(referentiel.errors.where(:url_tiptap, :missing_query_params)).to be_present
        end
      end

      context 'with a bare domain followed by a query' do
        let(:url_tiptap) { tiptap_url("https://data.gouv.fr?q=") }
        it { expect(referentiel).to be_valid }
      end

      # L'URL requêtée est le texte augmenté des valeurs de mention substituées : une mention
      # placée juste après l'hôte prolonge le nom de domaine. Le premier nœud doit donc
      # porter un domaine déjà clos.
      context 'with a mention appended to the host' do
        let(:url_tiptap) { tiptap_url("https://api.gouv.fr") }
        let(:referentiel) { build(:api_referentiel, :exact_match, url_tiptap:, test_data_tiptap: { "{query}" => "example.com" }) }

        it 'resolves the substituted value into the host' do
          resolved_host = Addressable::URI.parse(ReferentielService.new(referentiel:).test_url).host
          expect(resolved_host).to eq("api.gouv.frexample.com")
        end

        it 'adds tag_in_domain error' do
          referentiel.valid?
          expect(referentiel.errors).to be_of_kind(:url_tiptap, :tag_in_domain)
        end
      end

      context 'with the domain split across two text nodes' do
        let(:url_tiptap) do
          {
            "type" => "doc", "content" => [
              {
                "type" => "paragraph", "content" => [
                  { "type" => "text", "text" => "https://api" },
                  { "type" => "text", "text" => ".gouv.fr/v1/" },
                  { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
                ],
              },
            ],
          }
        end

        it 'adds tag_in_domain error' do
          referentiel.valid?
          expect(referentiel.errors).to be_of_kind(:url_tiptap, :tag_in_domain)
        end
      end
    end
  end
end
