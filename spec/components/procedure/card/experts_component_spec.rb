# frozen_string_literal: true

require "rails_helper"

RSpec.describe Procedure::Card::ExpertsComponent, type: :component do
  subject { render_inline(described_class.new(procedure:)) }

  context "when allow_expert_review is disabled" do
    let(:procedure) { create(:procedure, allow_expert_review: false) }

    it { is_expected.to have_css('p.fr-badge.fr-badge--info', text: "À configurer") }
  end

  context "when allow_expert_review is enabled" do
    let(:procedure) { create(:procedure, allow_expert_review: true) }

    it { is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Validé") }
  end
end
