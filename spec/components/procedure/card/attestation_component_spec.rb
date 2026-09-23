# frozen_string_literal: true

require "rails_helper"

RSpec.describe Procedure::Card::AttestationComponent, type: :component do
  let(:component) { described_class.new(procedure:, kind:) }

  subject { render_inline(component) }

  let(:procedure) { create(:procedure) }

  context 'acceptation' do
    let(:kind) { AttestationTemplate.kinds.fetch(:acceptation) }
    let!(:attestation_acceptation_template) { create(:attestation_template, procedure:, kind: :acceptation, activated:, version:) }

    context "when version is 2" do
      let(:version) { 2 }
      context "when AttestationAcceptation is enabled" do
        let(:activated) { true }
        it do
          is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Activée")
          is_expected.to have_css('h4.fr-h6', text: "Attestation d’acceptation")
          is_expected.to have_link(href: component.helpers.edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation))
        end
      end

      context "when AttestationAcceptation is disabled" do
        let(:activated) { false }
        it do
          is_expected.to have_css('p.fr-badge', text: "Désactivée")
          is_expected.to have_css('h4.fr-h6', text: "Attestation d’acceptation")
        end
      end
    end

    context "when version is 1" do
      let(:version) { 1 }
      context "when AttestationAcceptation is enabled" do
        let(:activated) { true }
        it { is_expected.to have_link(href: component.helpers.edit_admin_procedure_attestation_template_path(procedure)) }
      end
    end
  end

  context 'refus' do
    let(:kind) { AttestationTemplate.kinds.fetch(:refus) }
    let!(:attestation_refus_template) { create(:attestation_template, procedure:, kind: :refus, activated:, version: 2) }

    context "when AttestationRefus is enabled" do
      let(:activated) { true }
      it do
        is_expected.to have_css('p.fr-badge.fr-badge--success', text: "Activée")
        is_expected.to have_css('h4.fr-h6', text: "Attestation de refus")
        is_expected.to have_link(href: component.helpers.edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :refus))
      end
    end

    context "when AttestationRefus is disabled" do
      let(:activated) { false }
      it do
        is_expected.to have_css('p.fr-badge', text: "Désactivée")
        is_expected.to have_css('h4.fr-h6', text: "Attestation de refus")
      end
    end
  end
end
