# frozen_string_literal: true

RSpec.describe TypesDeChampEditor::HeaderSectionComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper
  let(:procedure) { create(:procedure, public_type_de_champs:) }

  let(:component) do
    cmp = nil
    form_for(tdc, url: '/') do |form|
      cmp = described_class.new(form:, coordinate: procedure.draft_revision.coordinate_for(tdc))
    end
    cmp
  end
  subject { render_inline(component).to_html }

  describe 'header_section_options_for_select' do
    context 'without upper tdc' do
      let(:public_type_de_champs) { [{ type: :header_section, level: 1 }] }
      let(:tdc) { procedure.draft_revision.public_root_type_de_champs.first }

      it 'allows up to level 1 header section' do
        expect(subject).to have_selector("option", count: 1)
      end
    end

    context 'with upper tdc of level 1' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 1 },
          { type: :header_section, level: 2 },
        ]
      end
      let(:tdc) { procedure.draft_revision.public_root_type_de_champs.last }

      it 'allows up to level 2 header section' do
        expect(subject).to have_selector("option", count: 2)
      end
    end

    context 'with upper tdc of level 2' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, level: 1 },
          { type: :header_section, level: 2 },
          { type: :header_section, level: 3 },
        ]
      end
      let(:tdc) { procedure.draft_revision.public_root_type_de_champs.third }

      it 'allows up to level 3 header section' do
        expect(subject).to have_selector("option", count: 3)
      end
    end

    context 'with error' do
      let(:public_type_de_champs) { [{ type: :header_section, level: 2 }] }
      let(:tdc) { procedure.draft_revision.public_root_type_de_champs.first }

      it 'includes disabled levels' do
        expect(subject).to have_selector("option", count: 3)
        expect(subject).to have_selector("option[disabled]", count: 2)
      end
    end
  end

  describe 'errors' do
    let(:public_type_de_champs) { [{ type: :header_section, level: 2 }] }
    let(:tdc) { procedure.draft_revision.public_root_type_de_champs.first }

    it 'returns errors' do
      expect(subject).to have_selector('.errors-summary')
    end
  end

  describe 'in the editor' do
    let(:revision) { procedure.draft_revision }
    let(:coordinate) { revision.revision_type_de_champs.joins(:type_de_champ).find_by(type_de_champ: { libelle: 'tested' }) }

    let(:level_select) { page.find("select[name$='[header_section_level]']") }

    # With the upper coordinates BlockComponent passes, to prove the header ignores them
    before { render_inline(TypesDeChampEditor::ChampComponent.new(coordinate:, upper_coordinates: coordinate.upper_coordinates)) }

    shared_examples 'offers level 1 only and shows the error the publication raises' do
      it do
        expect(page).to have_selector('.errors-summary')
        expect(level_select).to have_selector('option:not([disabled])', count: 1)
        expect(level_select).to have_selector('option[disabled]', count: 2)
      end
    end

    context 'for an annotation below public headers' do
      let(:procedure) do
        create(:procedure,
               public_type_de_champs: [{ type: :header_section, level: 1 }, { type: :header_section, level: 2 }],
               private_type_de_champs: [{ type: :header_section, libelle: 'tested', level: 2 }])
      end

      it_behaves_like 'offers level 1 only and shows the error the publication raises'
    end

    context 'for a header in a repetition below root headers' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :header_section, level: 1 },
          { type: :header_section, level: 2 },
          { type: :repetition, children: [{ type: :header_section, libelle: 'tested', level: 2 }] },
        ])
      end

      it_behaves_like 'offers level 1 only and shows the error the publication raises'
    end
  end
end
