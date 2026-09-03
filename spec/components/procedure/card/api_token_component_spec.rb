# frozen_string_literal: true

require "rails_helper"

RSpec.describe Procedure::Card::APITokenComponent, type: :component do
  subject { render_inline(described_class.new(procedure:)) }

  let(:procedure) { create(:procedure, api_entreprise_token:, api_particulier_token:) }

  context "API entreprise token and API particulier token are not configured" do
    let(:api_entreprise_token) { nil }
    let(:api_particulier_token) { nil }
    it do
      is_expected.to have_css('p.fr-badge.fr-badge--info', text: "À configurer")
      is_expected.to have_css('p.fr-tag', text: "0 / 2")
    end
  end

  context "API entreprise token expires soon" do
    let(:api_entreprise_token) { JWT.encode({ exp: 2.days.from_now.to_i }, nil, "none") }
    let(:api_particulier_token) { nil }
    it do
      is_expected.to have_css('p.fr-badge.fr-badge--error', text: "À renouveler")
      is_expected.to have_css('p.fr-tag', text: "1 / 2")
    end
  end

  context "API entreprise token expires in a long time" do
    let(:api_entreprise_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, "none") }
    let(:api_particulier_token) { nil }

    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Configuré")
      is_expected.to have_css('p.fr-tag', text: "1 / 2")
    end
  end

  context "API particulier token expires soon" do
    let(:api_entreprise_token) { nil }
    let(:api_particulier_token) { JWT.encode({ exp: 2.days.from_now.to_i }, nil, 'none') }

    it { is_expected.to have_css('p.fr-badge.fr-badge--error', text: "À renouveler") }
  end

  context "API particulier token is a legacy key" do
    let(:procedure) do
      create(:procedure).tap do
        it.api_particulier_token = 'd7e9c9f4c3ca00caadde31f50fd4521a'
        it.save(validate: false)
      end
    end

    it { is_expected.to have_css('p.fr-badge.fr-badge--error', text: "À renouveler") }
  end

  context "API entreprise token and API particulier token are both configured" do
    let(:api_entreprise_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, "none") }
    let(:api_particulier_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }
    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Configuré")
      is_expected.to have_css('p.fr-tag', text: "2 / 2")
    end
  end
end
