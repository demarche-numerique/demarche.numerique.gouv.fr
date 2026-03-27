# frozen_string_literal: true

describe TypesDeChampEditor::TypeDeChampSelectorComponent, type: :component do
  let(:procedure) { create(:procedure, :with_type_de_champ) }
  let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }

  before { render_inline(described_class.new(coordinate:)) }

  describe 'categories' do
    it 'renders 6 category groups in order' do
      groups = page.all('[data-category]').map { _1['data-category'] }
      expect(groups).to eq(%w[structure standard choice identification localisation referentiel])
    end
  end

  describe 'current type display' do
    it 'renders the trigger with current type label and icon' do
      trigger = page.find('[data-type-de-champ-selector-target="trigger"]')
      expect(trigger).to have_text('Texte court')
      expect(trigger).to have_css('.fr-icon-text')
    end
  end

  describe 'icons' do
    it 'renders icon class for each option' do
      options = page.all('[data-type-de-champ-selector-target="option"]')
      options.each do |option|
        type_champ = option['data-value']
        expected_icon = TypeDeChamp::TYPE_DE_CHAMP_TO_ICON[type_champ.to_sym]
        expect(option).to have_css(".#{expected_icon}"), "Missing icon for #{type_champ}"
      end
    end
  end

  describe 'disabled state' do
    context 'when used by routing rules' do
      before do
        allow(coordinate).to receive(:used_by_routing_rules?).and_return(true)
        render_inline(described_class.new(coordinate:))
      end

      it 'renders disabled trigger' do
        trigger = page.find('[data-type-de-champ-selector-target="trigger"]')
        expect(trigger['aria-disabled']).to eq('true')
        expect(trigger).to have_css('.fr-icon-lock-fill')
      end
    end
  end

  describe 'filtering' do
    context 'private annotation' do
      let(:procedure) { create(:procedure, :with_type_de_champ_private) }
      let(:coordinate) { procedure.draft_revision.revision_types_de_champ_private.first }

      it 'excludes public-only types' do
        values = page.all('[data-type-de-champ-selector-target="option"]').map { _1['data-value'] }
        expect(values).not_to include('quotient_familial')
      end
    end
  end

  describe 'ARIA attributes' do
    it 'renders combobox role on trigger with aria-controls' do
      trigger = page.find('[data-type-de-champ-selector-target="trigger"]')
      expect(trigger['role']).to eq('combobox')
      expect(trigger['aria-haspopup']).to eq('listbox')
      expect(trigger['aria-expanded']).to eq('false')
      expect(trigger['aria-controls']).to be_present
    end

    it 'renders listbox role on panel with matching id' do
      trigger = page.find('[data-type-de-champ-selector-target="trigger"]')
      panel = page.find('.type-de-champ-selector-panel[role="listbox"]')
      expect(panel['id']).to eq(trigger['aria-controls'])
    end

    it 'renders id on each option for aria-activedescendant' do
      options = page.all('[data-type-de-champ-selector-target="option"]')
      options.each do |option|
        expect(option['id']).to be_present, "Missing id for option #{option['data-value']}"
      end
    end

    it 'renders data-icon on each option' do
      options = page.all('[data-type-de-champ-selector-target="option"]')
      options.each do |option|
        expect(option['data-icon']).to be_present, "Missing data-icon for option #{option['data-value']}"
      end
    end
  end

  describe 'option ordering within categories' do
    it 'renders types in TYPE_DE_CHAMP_TO_CATEGORIE key order' do
      expected_order = TypeDeChamp::TYPE_DE_CHAMP_TO_CATEGORIE.keys.map(&:to_s)
      rendered_values = page.all('[data-type-de-champ-selector-target="option"]').map { _1['data-value'] }
      expect(rendered_values).to eq(rendered_values.sort_by { expected_order.index(_1) || Float::INFINITY })
    end
  end
end
