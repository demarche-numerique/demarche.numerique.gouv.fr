# frozen_string_literal: true

RSpec.describe TypesDeChampEditor::HeaderSectionsSummaryComponent, type: :component do
  include ActionView::RecordIdentifier

  subject { render_inline(component).to_html }

  let(:is_private) { false }
  let(:type_de_champs) do
    [
      { type: :header_section, level: 1, libelle: 'h1' },
      { type: :text },
      { type: :header_section, level: 2, libelle: 'h2' },
      { type: :repetition, children: [{ type: :text }, { type: :header_section, level: 1, libelle: 'rh1' }] },
      { type: :header_section, level: 3, libelle: 'h3' },
      { type: :text },
    ]
  end
  let(:procedure) { create(:procedure, public_type_de_champs: type_de_champs, private_type_de_champs: type_de_champs) }
  let(:component) { described_class.new(procedure:, is_private:) }
  let(:public_type_de_champs) { procedure.draft_revision.public_revision_type_de_champs.filter(&:header_section?) }
  let(:private_type_de_champs) { procedure.draft_revision.private_revision_type_de_champs.filter(&:header_section?) }

  context 'public' do
    it do
      public_type_de_champs.each { expect(subject).to have_selector("a[href='##{dom_id(_1, :type_de_champ_editor)}']") }
    end

    it 'marks the level of each section, leaving out the ones within a repetition' do
      expect(subject).to have_selector('a.fr-sidemenu__link:not(.custom-link-grey)', exact_text: 'h1')
      expect(subject).to have_selector('a.fr-sidemenu__link:not(.custom-link-grey)', exact_text: '-- h2')
      expect(subject).to have_selector('a.fr-sidemenu__link.custom-link-grey', exact_text: '-- h3')
      expect(subject).not_to have_text('rh1')
    end
  end

  context 'private' do
    let(:is_private) { true }
    it do
      private_type_de_champs.each { expect(subject).to have_selector("a[href='##{dom_id(_1, :type_de_champ_editor)}']") }
    end
  end
end
