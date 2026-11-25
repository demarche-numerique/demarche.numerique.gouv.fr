# frozen_string_literal: true

RSpec.describe Profile::APITokensTableComponent, type: :component do
  let(:owner) { administrateurs.default }
  let(:networks) { %w[10.0.0.0/8 192.168.1.0/24 172.16.8.0/22 2a01:e0a:1f2:4b30::/64 2001:db8:85a3::8a2e:370:7334/128].map { IPAddr.new(it) } }
  let(:modal) { page.find('dialog', visible: :all) }

  before { render_inline(described_class.new(labelledby: 'title', rows: [Profile::APITokenComponent.new(api_token:)])) }

  context 'with a token whose row shows everything' do
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [procedures.individual.id], authorized_networks: networks.first(3)).first }

    it { expect(page).to have_no_css('dialog', visible: :all) }
  end

  context 'with a token reading a procedure whose title gets cut' do
    let(:long_title) { procedures.individual.tap { it.update_column(:libelle, 'Demande d’aide exceptionnelle à destination des associations sportives agréées – volet 2') } }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [long_title.id]).first }

    it { expect(page).to have_button('Voir le détail') }
  end

  context 'with a token reading more networks and procedures than its row shows' do
    let(:four_procedures) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee] }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: four_procedures.map(&:id), authorized_networks: networks).first }

    it 'folds them in the row, and shows them all in the modal its button opens' do
      expect(page.all('td li code').map(&:text)).to eq(['10.0.0.0/8', '192.168.1.0/24', '172.16.8.0/22'])
      expect(page).to have_css('td p', exact_text: 'et 2 autres')
      expect(page.find_button('Voir le détail')['aria-controls']).to eq(modal['id'])

      expect(modal.all('li code', visible: :all).map { it.text(:all) }).to eq(['10.0.0.0/8', '192.168.1.0/24', '172.16.8.0/22', '2a01:e0a:1f2:4b30::/64', '2001:db8:85a3::8a2e:370:7334/128'])
      expect(modal.all('tbody tr', visible: :all).map { it.text(:all).squish }).to eq(four_procedures.sort_by(&:libelle).map { "#{it.id} #{it.libelle}" })
    end
  end
end
