# frozen_string_literal: true

describe 'administrateurs/referentiels/_test_data_fields', type: :view do
  let(:referentiel) { Referentiels::APIReferentiel.new }

  subject do
    render partial: 'administrateurs/referentiels/test_data_fields',
           locals: { referentiel:, test_data_tags: }
    rendered
  end

  context 'without tags' do
    let(:test_data_tags) { [] }

    it 'renders empty container' do
      expect(subject).to have_css('#test-data-fields')
      expect(subject).not_to have_css('table')
    end
  end

  context 'with tags' do
    let(:test_data_tags) { [{ id: "{query}", label: "Valeur saisie par l’usager" }] }

    it 'renders table with tag inputs' do
      expect(subject).to have_css('table')
      expect(subject).to have_css('span.fr-tag', text: "Valeur saisie par l’usager")
      expect(subject).to have_css('input[required][name="referentiel[test_data_tiptap][{query}]"]')
    end
  end

  context 'with existing test_data_tiptap values' do
    let(:test_data_tags) { [{ id: "{query}", label: "Query" }] }
    let(:referentiel) { Referentiels::APIReferentiel.new(test_data_tiptap: { "{query}" => "my-test-value" }) }

    it 'preserves values in inputs' do
      expect(subject).to have_css('input[value="my-test-value"]')
    end
  end

  context 'with validation errors' do
    let(:test_data_tags) { [{ id: "{query}", label: "Query" }] }
    let(:referentiel) do
      r = Referentiels::APIReferentiel.new
      r.errors.add(:"test_data_tiptap_{query}", "doit etre renseigne")
      r
    end

    it 'renders DSFR error styling' do
      expect(subject).to have_css('.fr-input-group--error')
      expect(subject).to have_css('input[aria-invalid]')
      expect(subject).to have_css('p.fr-error-text', text: 'Valeur de test requise')
    end
  end
end
