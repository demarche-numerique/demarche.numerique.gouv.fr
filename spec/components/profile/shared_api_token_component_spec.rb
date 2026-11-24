# frozen_string_literal: true

RSpec.describe Profile::SharedAPITokenComponent, type: :component do
  include ActionView::RecordIdentifier

  let(:owner) { administrateurs.default }
  let(:shared) { procedures.individual }
  let(:reader_procedure_ids) { [shared.id] }
  let(:legend) { page.find("td[headers='#{dom_id(api_token, :shared_name)}']") }

  before { render_inline(described_class.new(api_token:, reader_procedure_ids:)) }

  context 'with a read-only list token' do
    let(:api_token) { APIToken.generate(owner, name: 'Tableau', write_access: false, allowed_procedure_ids: [shared.id, procedures.brouillon.id], follows_clones: true).first }

    it 'tells who manages it, and names only the procedures we share' do
      expect(page).to have_css("tbody##{dom_id(api_token, :shared)} th", text: "Géré par #{owner.email}")
      expect(page).to have_css('td', exact_text: 'Lecture seule')
      expect(legend).to have_text("Démarches : #{shared.libelle} (n° #{shared.id}) et 1 autre démarche de #{owner.email} et leurs futurs clones")
      expect(legend).to have_link("#{shared.libelle} (n° #{shared.id})", href: "/admin/procedures/#{shared.id}")
      expect(legend).to have_no_text(procedures.brouillon.libelle)
    end
  end

  context 'with a full access token' do
    let(:api_token) { APIToken.generate(owner).first }

    it { expect(legend.all('.fr-hint-text').last.text.strip).to eq("Démarches : Toutes les démarches de #{owner.email}, dont : #{shared.libelle} (n° #{shared.id})") }
  end

  context 'when we share more procedures than the legend names' do
    let(:reader_procedure_ids) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee].map(&:id) }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: reader_procedure_ids).first }

    it { expect(legend).to have_text('Démarches : 4 démarches que vous administrez') }
  end
end
