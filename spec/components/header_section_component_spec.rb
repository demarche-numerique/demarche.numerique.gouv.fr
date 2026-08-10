# frozen_string_literal: true

RSpec.describe TypesDeChampEditor::HeaderSectionComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper
  let(:procedure) { create(:procedure, types_de_champ_public:) }

  let(:component) do
    cmp = nil
    form_for(tdc, url: '/') do |form|
      cmp = described_class.new(form: form, tdc: tdc, upper_tdcs: upper_tdcs)
    end
    cmp
  end
  subject { render_inline(component).to_html }

  describe 'header_section_options_for_select' do
    context 'without upper tdc' do
      let(:types_de_champ_public) { [{ type: :header_section, level: 1 }] }
      let(:tdc) { procedure.draft_revision.root_public_types_de_champ.first }
      let(:upper_tdcs) { [] }

      it 'allows up to level 1 header section' do
        expect(subject).to have_selector("option", count: 1)
      end
    end

    context 'with upper tdc of level 1' do
      let(:types_de_champ_public) do
        [
          { type: :header_section, level: 1 },
          { type: :header_section, level: 2 },
        ]
      end
      let(:tdc) { procedure.draft_revision.root_public_types_de_champ.last }
      let(:upper_tdcs) { [procedure.draft_revision.root_public_types_de_champ.first] }

      it 'allows up to level 2 header section' do
        expect(subject).to have_selector("option", count: 2)
      end
    end

    context 'with upper tdc of level 2' do
      let(:types_de_champ_public) do
        [
          { type: :header_section, level: 1 },
          { type: :header_section, level: 2 },
          { type: :header_section, level: 3 },
        ]
      end
      let(:tdc) { procedure.draft_revision.root_public_types_de_champ.third }
      let(:upper_tdcs) { [procedure.draft_revision.root_public_types_de_champ.first, procedure.draft_revision.root_public_types_de_champ.second] }

      it 'allows up to level 3 header section' do
        expect(subject).to have_selector("option", count: 3)
      end
    end

    context 'with error' do
      let(:types_de_champ_public) { [{ type: :header_section, level: 2 }] }
      let(:tdc) { procedure.draft_revision.root_public_types_de_champ.first }
      let(:upper_tdcs) { [] }

      it 'includes disabled levels' do
        expect(subject).to have_selector("option", count: 3)
        expect(subject).to have_selector("option[disabled]", count: 2)
      end
    end
  end

  describe 'errors' do
    let(:types_de_champ_public) { [{ type: :header_section, level: 2 }] }
    let(:tdc) { procedure.draft_revision.root_public_types_de_champ.first }
    let(:upper_tdcs) { [] }

    it 'returns errors' do
      expect(subject).to have_selector('.errors-summary')
    end
  end
end
