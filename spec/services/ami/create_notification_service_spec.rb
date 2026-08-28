# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::CreateNotificationService do
  include ActiveJob::TestHelper

  describe '.call' do
    let(:procedure) { create(:procedure, :published, :for_individual) }
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, user:) }
    let(:payload) { { recipient_fc_hash: "abc123", item_id: dossier.id.to_s } }

    before do
      clear_enqueued_jobs
      allow_any_instance_of(Ami::Client).to receive(:configured?).and_return(true)
      allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(true)
      allow(Ami::RecipientFcHash).to receive(:call).and_return("abc123")
    end

    it 'enqueues send job with payload snapshot and context' do
      expect { described_class.call(dossier:) }.to have_enqueued_job(Ami::SendNotificationJob)

      args = enqueued_jobs.last.fetch(:args)
      expect(args.first).to include("recipient_fc_hash" => payload.fetch(:recipient_fc_hash), "item_id" => payload.fetch(:item_id))
      expect(args.second).to include("procedure" => dossier.procedure.id, "dossier" => dossier.id)
      expect(args.second.dig("state", "value")).to eq(dossier.state)
    end

    it 'lets the notification carry the consent when asked to' do
      described_class.call(dossier:, skip_consent_check: true)

      expect(Ami::SendNotificationJob).to have_been_enqueued.with(anything, anything, skip_consent_check: true)
    end

    it 'does not carry the consent by default' do
      described_class.call(dossier:)

      expect(Ami::SendNotificationJob).to have_been_enqueued.with(anything, anything, skip_consent_check: false)
    end

    it 'does not enqueue when feature flag is disabled' do
      allow_any_instance_of(Procedure).to receive(:feature_enabled?).with(:ami_notifications).and_return(false)

      expect { described_class.call(dossier:) }.not_to have_enqueued_job(Ami::SendNotificationJob)
    end

    it 'does not enqueue when recipient hash is missing (ex no FranceConnect information)' do
      allow(Ami::RecipientFcHash).to receive(:call).and_return(nil)

      expect { described_class.call(dossier:) }.not_to have_enqueued_job(Ami::SendNotificationJob)
    end

    context 'when dossier is brouillon' do
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:, user:) }

      it 'enqueues send job' do
        expect { described_class.call(dossier:) }.to have_enqueued_job(Ami::SendNotificationJob)
      end
    end
  end

  describe '#create_notification_payload' do
    let(:procedure) { create(:procedure, :published, :for_individual) }
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, user:) }
    let(:event_date) { "2026-03-02T12:34:56+01:00" }

    before do
      create(
        :france_connect_information,
        user:,
        given_name: "Jean",
        family_name: "Dupont",
        birthdate: Date.parse("1980-05-04"),
        gender: "male",
        birthplace: "Paris",
        birthcountry: "France"
      )
    end

    it 'builds the expected payload contract' do
      payload = described_class.new(dossier:, trigger: :dossier_state_change, state: nil).create_notification_payload(event_date:)

      expect(payload).to include(
        recipient_fc_hash: kind_of(String),
        content_title: kind_of(String),
        content_body: kind_of(String),
        item_type: dossier.procedure.id.to_s,
        item_id: dossier.id.to_s,
        item_status_label: "En\u00a0instruction",
        item_generic_status: "wip",
        item_canal: described_class::SOURCE,
        content_link: kind_of(String),
        event_date:
      )
    end

    it 'uses the same wording as the user notification email subject' do
      payload = described_class.new(dossier:, trigger: :dossier_state_change, state: nil).create_notification_payload(event_date:)

      expect(payload).to include(
        content_title: APPLICATION_NAME,
        content_body: dossier.email_template_for(Dossier.states.fetch(:en_instruction)).subject_for_dossier(dossier)
      )
    end

    context 'when dossier is brouillon' do
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:, user:) }

      it 'builds a creation-oriented payload' do
        payload = described_class.new(dossier:, trigger: :dossier_state_change, state: nil).create_notification_payload(event_date:)

        expect(payload).to include(
          content_title: APPLICATION_NAME,
          content_body: I18n.t("dossier_mailer.notify_new_draft.subject", libelle_demarche: dossier.procedure.libelle),
          item_generic_status: "new"
        )
      end
    end

    context 'when triggered by a messagerie message' do
      it 'builds a messagerie-oriented payload' do
        payload = described_class.new(dossier:, trigger: :messagerie_message, state: nil).create_notification_payload(event_date:)

        expect(payload).to include(
          content_title: APPLICATION_NAME,
          content_body: I18n.t("dossier_mailer.notify_new_answer.subject", dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle),
          item_generic_status: "wip"
        )
      end
    end
  end
end
