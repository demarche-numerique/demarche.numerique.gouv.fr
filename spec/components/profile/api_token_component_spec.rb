# frozen_string_literal: true

RSpec.describe Profile::APITokenComponent, type: :component do
  let(:owner) { administrateurs.default }
  let(:listed) { [procedures.individual, procedures.brouillon] }
  let(:api_token) do
    APIToken.generate(owner, name: 'Export', allowed_procedure_ids: listed.map(&:id), follows_clones: true, authorized_networks: [IPAddr.new('192.168.1.0/24'), IPAddr.new('10.0.0.1')]).first
  end
  let(:cells) { page.all('th[scope="row"], td').map { it.text.squish } }

  before do
    travel_to Date.new(2026, 11, 25)
    render_inline(described_class.new(api_token:))
  end

  it 'gives the token one row: who it is, what it reads, until when' do
    expect(cells[0]).to eq("Export Lecture et écriture Commence par #{api_token.prefix}")
    expect(page.all('.fr-raw-list li').map(&:text)).to eq([
      "n° #{procedures.individual.id} #{procedures.individual.libelle}",
      "n° #{procedures.brouillon.id} #{procedures.brouillon.libelle}",
      '192.168.1.0/24',
      '10.0.0.1/32',
    ])
    expect(page).to have_link(procedures.individual.libelle, href: "/admin/procedures/#{procedures.individual.id}")
    expect(page).to have_css('td p', exact_text: 'et leurs futurs clones')
    expect(cells[2]).to eq('Expire le 25/11/2027 Dernier appel Jamais')
    expect(page.all('.fr-btn').map { it['aria-label'] }).to eq(["Modifier le jeton « Export »", "Dupliquer le jeton « Export »", "Supprimer le jeton « Export »"])
    expect(page.find_link('Supprimer')['data-turbo-confirm']).to eq("Confirmez-vous la suppression du jeton «\u00A0Export\u00A0»\u00A0?")
  end

  context 'when the token was used 3 hours ago' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_column(:last_v2_authenticated_at, 3.hours.ago) } }

    it { expect(cells[2]).to end_with('Dernier appel Il y a 3 heures') }
  end

  context 'when the token expires in 9 days' do
    let(:api_token) { APIToken.generate(owner, expires_at: Date.new(2026, 12, 4)).first }

    it { expect(cells[2]).to start_with('Expire le 04/12/2026 Dans 9 jours') }
  end

  context 'when the token expired before its first call' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_column(:expires_at, Date.new(2026, 1, 28)) } }

    it 'can no longer be edited, nor waits for that call' do
      expect(cells[2]).to start_with('Expiré le 28/01/2026')
      expect(page).to have_css('td p', exact_text: 'Aucune')
      expect(page).to have_no_link('Modifier')
    end
  end

  context 'when the token lists more procedures than the row names' do
    let(:listed) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee] }

    it { expect(page).to have_css('td p', exact_text: '4 démarches et leurs futurs clones') }
  end

  context 'when the token filters no network' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_column(:requires_ip_filtering, false) } }

    it { expect(page).to have_css('.fr-badge--warning', text: 'Aucun filtrage réseau') }
  end
end
