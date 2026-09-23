# frozen_string_literal: true

RSpec.describe Procedure::Card::ServiceComponent, type: :component do
  subject { render_inline(described_class.new(procedure:, administrateur:)) }

  let(:administrateur) { create(:administrateur) }

  context 'when the procedure has a service' do
    let(:service) { create(:service, administrateur:, nom: 'DINUM') }
    let(:procedure) { create(:procedure, service:) }

    it do
      is_expected.to have_css('a#service')
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: 'Validé')
      is_expected.to have_css('p.fr-tile-subtitle', text: 'DINUM')
      is_expected.to have_css('p.fr-btn', text: 'Modifier')
    end
  end

  context 'when the procedure has no service' do
    let(:procedure) { create(:procedure, service: nil) }

    it 'offers to fill one in' do
      is_expected.to have_css('p.fr-badge.fr-badge--warning', text: 'À faire')
      is_expected.to have_css('p.fr-tile-subtitle', text: 'Choix du service administratif')
      is_expected.to have_css('p.fr-btn', text: 'Remplir')
    end

    context 'and the administrateur already has services' do
      before { create(:service, administrateur:) }

      it { is_expected.to have_css('p.fr-btn', text: 'Choisir') }
    end
  end
end
