# frozen_string_literal: true

RSpec.describe Profile::APITokensTableComponent, type: :component do
  let(:owner) { administrateurs.default }
  let(:four_procedures) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee] }
  let(:networks) { %w[10.0.0.0/8 192.168.1.0/24 172.16.8.0/22 2a01:e0a:1f2:4b30::/64 2001:db8:85a3::8a2e:370:7334/128].map { IPAddr.new(it) } }
  let(:legend) { page.find('td[colspan="4"]') }
  let(:modal) { page.find('dialog.fr-modal', visible: :all) }

  before { render_inline(described_class.new(labelledby: 'title', rows:)) }

  context 'with a token whose legend names everything' do
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [procedures.individual.id], authorized_networks: networks.first(3)).first }
    let(:rows) { [Profile::APITokenComponent.new(api_token:)] }

    it 'needs no modal' do
      expect(page).to have_no_button('Voir le détail')
      expect(page).to have_no_css('dialog', visible: :all)
    end
  end

  context 'with a token reading more networks and procedures than its legend names' do
    let(:api_token) { APIToken.generate(owner, name: 'Export', allowed_procedure_ids: four_procedures.map(&:id), authorized_networks: networks).first }
    let(:rows) { [Profile::APITokenComponent.new(api_token:)] }

    it 'folds them, and shows them all in a modal after the table' do
      expect(legend).to have_text('Adresses IP : 10.0.0.0/8, 192.168.1.0/24, 172.16.8.0/22 et 2 autres')
      expect(legend.find('button', text: 'Voir le détail')['aria-label']).to eq('Voir le détail du jeton « Export »')
      expect(legend.find('button')['aria-controls']).to eq(modal['id'])
      expect(page).to have_css('.fr-table ~ dialog', visible: :all)

      expect(modal).to have_css('.fr-modal__title', text: 'Jeton « Export »', visible: :all)
      expect(modal.all('li code', visible: :all).map { it.text(:all) }).to eq(['10.0.0.0/8', '192.168.1.0/24', '172.16.8.0/22', '2a01:e0a:1f2:4b30::/64', '2001:db8:85a3::8a2e:370:7334/128'])
      expect(modal.all('tbody tr', visible: :all).map { it.text(:all).squish }).to eq(four_procedures.sort_by(&:libelle).map { "#{it.id} #{it.libelle}" })
      expect(modal).to have_link(procedures.close.libelle, href: "/admin/procedures/#{procedures.close.id}", visible: :all)
    end
  end

  context 'with the token of a co-administrator sharing more procedures than its legend names' do
    let(:other) { procedures.entreprise }
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [*four_procedures, other].map(&:id)).first }
    let(:rows) { [Profile::SharedAPITokenComponent.new(api_token:, reader_procedure_ids: four_procedures.map(&:id))] }

    it 'names in the modal the shared procedures only' do
      expect(modal).to have_text(:all, "4 démarches que vous administrez et 1 autre démarche de #{owner.email}")
      expect(modal.all('tbody tr', visible: :all).map { it.text(:all).squish }).to eq(four_procedures.sort_by(&:libelle).map { "#{it.id} #{it.libelle}" })
      expect(modal).to have_no_text(:all, other.libelle)
    end
  end
end
