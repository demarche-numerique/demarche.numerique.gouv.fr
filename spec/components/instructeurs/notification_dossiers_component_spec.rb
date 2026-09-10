# frozen_string_literal: true

RSpec.describe Instructeurs::NotificationDossiersComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:statut) { 'a-suivre' }
  let(:procedure_id) { 42 }
  let(:component) { described_class.new(dossiers:, statut:, procedure_id:) }

  # No need to hit the database: the component only reads the id and the owner name.
  def build_dossier(id, nom)
    Dossier.new(id:, individual: Individual.new(nom:, prenom: 'Jean'))
  end

  before { render_inline(component) }

  context 'when every dossier fits on the line' do
    let(:dossiers) { (1..3).map { build_dossier(it, 'DUPONT') } }

    it 'links every dossier without an indicator' do
      expect(page).to have_css('li.notification-dossier', count: 3)
      expect(page).to have_link('1', href: instructeur_dossier_path(procedure_id, 1))
      expect(page).to have_text('DUPONT Jean', count: 3)
      expect(page).not_to have_css('.notification-indicator')
    end
  end

  context 'when the list overflows the line' do
    # "100001 DUPONT Jean" is 18 characters, i.e. 144px + a 33px separator:
    # 5 of them fit in the 876px line, but only 4 once the indicator takes its 80px.
    let(:dossiers) { (1..10).map { build_dossier(100_000 + it, 'DUPONT') } }

    it 'cuts the list and sums up the rest' do
      expect(page).to have_css('li.notification-dossier', count: 4)
      expect(page).to have_link('100004')
      expect(page).not_to have_link('100005')
      expect(page).to have_css('li.notification-indicator', text: '(+ 6)')
      expect(page).to have_css('.fr-sr-only', text: 'et 6 autres dossiers')
    end
  end

  context 'when the first owner name alone overflows the line' do
    let(:dossiers) { [build_dossier(1, 'A' * 200), build_dossier(2, 'DUPONT')] }

    it 'still shows the first dossier' do
      expect(page).to have_css('li.notification-dossier', count: 1)
      expect(page).to have_link('1')
      expect(page).to have_css('li.notification-indicator', text: '(+ 1)')
      expect(page).to have_css('.fr-sr-only', text: 'et un autre dossier')
    end
  end

  context 'when the dossier has no owner yet' do
    let(:dossiers) { [Dossier.new(id: 1)] }

    it 'renders the dossier number alone' do
      expect(page).to have_link('1', href: instructeur_dossier_path(procedure_id, 1))
    end
  end

  context 'with deleted dossiers' do
    let(:statut) { 'supprimes' }
    let(:dossiers) { [build_dossier(1, 'DUPONT')] }

    it 'does not link the dossier' do
      expect(page).not_to have_link('1')
      expect(page).to have_css('li.notification-dossier span', exact_text: '1')
      expect(page).to have_css('li.notification-dossier', text: 'DUPONT Jean')
    end
  end
end
