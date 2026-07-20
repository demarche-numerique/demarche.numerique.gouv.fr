# frozen_string_literal: true

RSpec.describe ViewableChamp::HeaderSectionsSummaryComponent, type: :component do
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
  let(:procedure) { build(:procedure, types_de_champ_public: types_de_champ, types_de_champ_private: types_de_champ) }
  let(:dossier) { build(:dossier, procedure:) }
  let(:component) { described_class.new(dossier:, is_private:) }
  let(:types_de_champ_public) { dossier.root_types_de_champ_public.filter(&:header_section?) }
  let(:types_de_champ_private) { dossier.root_types_de_champ_private.filter(&:header_section?) }

  context 'public' do
    it do
      types_de_champ_public.each { expect(subject).to have_selector("a[href='##{_1.html_id}']") }
    end
  end

  context 'private' do
    let(:is_private) { true }
    it do
      types_de_champ_private.each { expect(subject).to have_selector("a[href='##{_1.html_id}']") }
    end
  end
end
