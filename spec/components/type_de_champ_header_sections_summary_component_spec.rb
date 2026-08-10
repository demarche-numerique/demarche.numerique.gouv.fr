# frozen_string_literal: true

RSpec.describe TypesDeChampEditor::HeaderSectionsSummaryComponent, type: :component do
  include ActionView::RecordIdentifier

  subject { render_inline(component).to_html }

  let(:is_private) { false }
  let(:types_de_champ) do
    [
      { type: :header_section, level: 1 },
      { type: :text },
      { type: :header_section, level: 2 },
      { type: :repetition, children: [{ type: :text }, { type: :header_section, level: 1 }] },
      { type: :header_section, level: 3 },
      { type: :text },
    ]
  end
  let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ, types_de_champ_private: types_de_champ) }
  let(:component) { described_class.new(procedure:, is_private:) }
  let(:types_de_champ_public) { procedure.draft_revision.public_revision_types_de_champ.filter(&:header_section?) }
  let(:types_de_champ_private) { procedure.draft_revision.private_revision_types_de_champ.filter(&:header_section?) }

  context 'public' do
    it do
      types_de_champ_public.each { expect(subject).to have_selector("a[href='##{dom_id(_1, :type_de_champ_editor)}']") }
    end
  end

  context 'private' do
    let(:is_private) { true }
    it do
      types_de_champ_private.each { expect(subject).to have_selector("a[href='##{dom_id(_1, :type_de_champ_editor)}']") }
    end
  end
end
