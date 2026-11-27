# frozen_string_literal: true

describe Dossiers::LinkComponent, type: :component do
  let(:procedure) { create(:procedure, private_type_de_champs: [{ type: :link }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { it.update_columns(value:) } }

  before { render_inline(described_class.new(champ:)) }

  context 'with an https url' do
    let(:value) { 'https://outil-metier.gouv.fr/dossiers/42' }

    it { expect(page).to have_link(value, href: value) }
  end

  context 'with a value that is not an http(s) url' do
    let(:value) { 'javascript:alert(1)' }

    it 'shows it as text' do
      expect(page).to have_no_link
      expect(page).to have_text(value)
    end
  end
end
