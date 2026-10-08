# frozen_string_literal: true

require "rails_helper"

RSpec.describe 'administrateurs/groupe_instructeurs routing modals', type: :view do
  before_all { seed "cases/routage" }

  let(:modal_html) { rendered }

  context 'custom routing' do
    before { render partial: 'administrateurs/groupe_instructeurs/custom_routing_modal' }

    it_behaves_like 'a labelled DSFR modal', 'routing-mode-modal'
    it { expect(rendered).to have_css('dialog#routing-mode-modal[data-controller="auto-open-modal"]', visible: :all) }
  end

  context 'simple routing' do
    let(:procedure) { procedures.routee }

    before do
      # the seeded procedure routes on no champ: give the title something to show
      allow(procedure).to receive(:routing_champs).and_return(['Département'])
      render partial: 'administrateurs/groupe_instructeurs/simple_routing_modal', locals: { procedure: }
    end

    it_behaves_like 'a labelled DSFR modal', 'routing-mode-modal'
    # the guillemets are padded with non-breaking spaces
    it { expect(rendered).to have_text(/Les groupes instructeurs ont été créés à partir du champ «[[:space:]]Département[[:space:]]»/) }
  end
end
