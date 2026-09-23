# frozen_string_literal: true

require "rails_helper"

RSpec.describe Procedure::Card::RdvComponent, type: :component do
  before do
    allow_any_instance_of(described_class).to receive(:feature_enabled?).and_return(true)
  end

  subject { render_inline(described_class.new(procedure:)) }

  let(:procedure) { create(:procedure, rdv_enabled:) }

  context "when RDV is enabled" do
    let(:rdv_enabled) { true }

    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Activée")
      is_expected.to have_css('h4.fr-h6', text: "Prise de rendez-vous")
    end
  end

  context "when RDV is disabled" do
    let(:rdv_enabled) { false }

    it do
      is_expected.to have_css('p.fr-badge', text: "Désactivée")
      is_expected.to have_css('h4.fr-h6', text: "Prise de rendez-vous")
    end
  end
end
