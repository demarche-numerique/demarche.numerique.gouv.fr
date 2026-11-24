# frozen_string_literal: true

RSpec.describe Profile::SharedAPITokenComponent, type: :component do
  let(:owner) { administrateurs.default }
  let(:shared) { procedures.individual }
  let(:reader_procedure_ids) { [shared.id] }

  before { render_inline(described_class.new(api_token:, reader_procedure_ids:)) }

  context 'with a read-only list token' do
    let(:api_token) { APIToken.generate(owner, name: 'Tableau', write_access: false, allowed_procedure_ids: [shared.id, procedures.brouillon.id], follows_clones: true).first }

    it 'tells who manages it, and names only the procedures we share' do
      expect(page).to have_css('th', text: "Géré par #{owner.email}")
      expect(page).to have_link(shared.libelle, href: "/admin/procedures/#{shared.id}")
      expect(page).to have_css('td p', exact_text: "et 1 autre démarche de #{owner.email} et leurs futurs clones")
      expect(page).to have_no_text(procedures.brouillon.libelle)
    end

    it 'only offers to duplicate it' do
      expect(page.all('.fr-btn').map { it['aria-label'] }).to eq(["Dupliquer le jeton «\u00A0Tableau\u00A0» de #{owner.email}"])
    end
  end

  context 'with a full access token' do
    let(:api_token) { APIToken.generate(owner).first }

    it 'names the procedures we share among all those of its owner' do
      expect(page).to have_link(shared.libelle)
      expect(page).to have_css('td p', exact_text: "parmi toutes les démarches de #{owner.email}")
    end
  end

  context 'when we share more procedures than the row names' do
    let(:reader_procedure_ids) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee].map(&:id) }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: reader_procedure_ids).first }

    it { expect(page).to have_css('td p', exact_text: '4 démarches que vous administrez') }
  end
end
