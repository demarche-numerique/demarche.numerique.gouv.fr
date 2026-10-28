# frozen_string_literal: true

require "rails_helper"

RSpec.describe Procedure::Card::RdvComponent, type: :component do
  before do
    stub_const('ENV', ENV.to_hash.merge('RDV_SERVICE_PUBLIC_OAUTH_APP_ID' => rdv_oauth_app_id))
  end

  subject { render_inline(described_class.new(procedure:)) }

  let(:rdv_oauth_app_id) { 'rdv-app-id' }
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

  context "when the instance is not connected to RDV Service Public" do
    let(:rdv_oauth_app_id) { '' }
    let(:rdv_enabled) { true }

    it { is_expected.not_to have_css('h4.fr-h6', text: "Prise de rendez-vous") }
  end
end
