# frozen_string_literal: true

RSpec.describe Profile::APITokenComponent, type: :component do
  include ActionView::RecordIdentifier

  let(:owner) { administrateurs.default }
  let(:recipient) { administrateurs.blank }
  let(:listed) { [procedures.individual, procedures.brouillon] }
  let(:api_token) do
    APIToken.generate(owner, name: 'Export', allowed_procedure_ids: listed.map(&:id), follows_clones: true, authorized_networks: [IPAddr.new('192.168.1.0/24'), IPAddr.new('10.0.0.1')]).first
  end
  let(:legend) { page.find("td[headers='#{dom_id(api_token, :name)}']") }

  before { render_inline(described_class.new(api_token:)) }

  it 'gives the token a row, and a legend under it' do
    expect(page).to have_css("tbody##{dom_id(api_token)} > tr", count: 2)
    expect(page).to have_css('th[scope="row"][rowspan="2"]', text: /Export\s+Commence par #{api_token.prefix}/)
    expect(legend).to have_text("Adresses IP : 192.168.1.0/24, 10.0.0.1/32")
    expect(legend).to have_text("Démarches : #{procedures.individual.libelle} (n° #{procedures.individual.id}), #{procedures.brouillon.libelle} (n° #{procedures.brouillon.id}) et leurs futurs clones")
    expect(legend).to have_link("#{procedures.individual.libelle} (n° #{procedures.individual.id})", href: "/admin/procedures/#{procedures.individual.id}")
  end

  it 'makes editing the main action, each action naming the token' do
    expect(page).to have_css("a.fr-btn--secondary[aria-label='Modifier le jeton « Export »']", text: 'Modifier')
    expect(page).to have_css("button.fr-btn--tertiary[aria-label='Dupliquer le jeton « Export »']", text: 'Dupliquer')
    expect(page).to have_css("a.fr-btn--tertiary[aria-label='Supprimer le jeton « Export »'][data-turbo-confirm='Confirmez-vous la suppression du jeton « Export » ?']", text: 'Supprimer')
  end

  context 'when the token was used 3 hours ago' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_column(:last_v2_authenticated_at, 3.hours.ago) } }

    it { expect(page).to have_css('td', exact_text: 'Il y a 3 heures') }
  end

  context 'when the token expired' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_columns(expires_at: 1.day.ago.to_date, transfer_recipient_id: recipient.id) } }

    it 'offers to duplicate it rather than to edit it, and no longer mentions its inert hand-over' do
      expect(page).to have_css('.fr-badge--error', text: 'Expiré')
      expect(page).to have_css('button.fr-btn--secondary', text: 'Dupliquer')
      expect(page).to have_no_link('Modifier')
      expect(page).to have_no_text('Transmission proposée')
    end
  end

  context 'when the token lists more procedures than the legend names' do
    let(:listed) { [procedures.individual, procedures.brouillon, procedures.close, procedures.depubliee] }

    it { expect(legend).to have_text("Démarches : 4 démarches et leurs futurs clones") }
  end

  context 'when the token filters no network' do
    let(:api_token) { APIToken.generate(owner).first.tap { it.update_column(:requires_ip_filtering, false) } }

    it { expect(legend).to have_css('.fr-badge--warning', text: 'Aucun filtrage réseau') }
  end

  context 'when the token is offered to a co-administrateur' do
    let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: listed.map(&:id)).first.tap { it.update_column(:transfer_recipient_id, recipient.id) } }

    it 'tells to whom, and leaves the hand-over to the edit page' do
      expect(page).to have_css('th', text: "Transmission proposée à #{recipient.email}")
      expect(page).to have_no_link('Transmettre')
      expect(page).to have_no_button('Annuler la transmission')
    end
  end
end
