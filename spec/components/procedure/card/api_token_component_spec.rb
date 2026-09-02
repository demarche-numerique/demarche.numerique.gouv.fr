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

  context "API entreprise token and API particulier token are both configured" do
    let(:api_entreprise_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, "none") }
    let(:api_particulier_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }
    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Configuré")
      is_expected.to have_css('p.fr-tag', text: "2 / 2")
    end
  end

  context "API particulier token cannot be decoded" do
    # Le cas de RAILS-MGX, tel que l'administrateur le verra sur sa tuile Jetons.
    let(:procedure) do
      create(:procedure).tap do
        it.api_particulier_token = 'azertyuiopqsdfgh'
        it.save(validate: false)
      end
    end

    it { is_expected.to have_css('p.fr-badge.fr-badge--error', text: "À renouveler") }
  end
end
