# frozen_string_literal: true

describe TypesDeChamp::ReferentielTypeDeChamp do
  describe '#ensure_exclusive_referentiel!' do
    let(:autocomplete_configuration) { { 'datasource' => '$.records', 'json_template' => { 'type' => 'doc' }, 'result_path' => '$.records[0]' } }
    let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response, hint: 'partagé', autocomplete_configuration:) }
    let(:type_de_champ) { create(:type_de_champ_referentiel, referentiel:) }

    context 'when the referentiel is used by this champ only' do
      it 'keeps it' do
        expect(type_de_champ.ensure_exclusive_referentiel!).to eq(referentiel)
      end
    end

    context 'when the referentiel is shared with a champ of another revision' do
      let!(:other_type_de_champ) { create(:type_de_champ_referentiel, referentiel:) }

      it 'moves this champ to a copy and leaves the other champ on the original' do
        copy = type_de_champ.ensure_exclusive_referentiel!

        expect(copy).not_to eq(referentiel)
        expect(copy.hint).to eq('partagé')
        expect(copy.url_tiptap).to eq(referentiel.url_tiptap)
        expect(copy.last_response).to eq(referentiel.last_response)
        expect(copy.autocomplete_configuration).to eq(autocomplete_configuration)
        expect(type_de_champ.reload.referentiel).to eq(copy)
        expect(other_type_de_champ.reload.referentiel).to eq(referentiel)
      end

      context 'when the referentiel no longer passes validation' do
        before { referentiel.update_column(:test_data_tiptap, {}) }

        it 'still moves this champ to a persisted copy' do
          copy = type_de_champ.ensure_exclusive_referentiel!

          expect(copy).to be_persisted
          expect(type_de_champ.reload.referentiel).to eq(copy)
        end
      end
    end
  end

  describe "#referentiel_url_as_text" do
    let(:referentiel) do
      create(:api_referentiel, :exact_match).tap do |referentiel|
        referentiel.update!(url_tiptap: {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
              "content" => [
                { "type" => "text", "text" => "https://example.gouv.fr/?a=" },
                { "type" => "mention", "attrs" => { "id" => "1234", "label" => "Un autre champ" } },
                { "type" => "text", "text" => "&q=" },
                { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
              ],
            },
          ],
        }, test_data_tiptap: { "{query}" => "PG46YY6YWCX8", "1234" => "42" })
      end
    end

    let(:type_de_champ) { create(:type_de_champ_referentiel, referentiel:) }

    it "renders every mention with its label" do
      expect(type_de_champ.referentiel_url_as_text).to eq("https://example.gouv.fr/?a={Un autre champ}&q={Valeur saisie par l'usager}")
    end
  end
end
