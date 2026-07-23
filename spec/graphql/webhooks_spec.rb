# frozen_string_literal: true

RSpec.describe Types::WebhookType, type: :graphql do
  let(:admin) { administrateurs.default }
  let(:procedure) { procedures.individual }
  let(:webhook) { webhooks.default }
  let(:context) { { administrateur_id: admin.id, procedure_ids: admin.procedure_ids, write_access: true, remote_ip: '192.168.1.23' } }
  let(:variables) { {} }
  let(:query) { '' }

  subject { API::V2::Schema.execute(query, variables:, context:) }

  let(:data) { subject['data'].deep_symbolize_keys }
  let(:errors) { subject['errors'] }

  before { Flipper.enable(:webhooks_api, procedure) }

  describe 'webhooks query' do
    let(:query) { WEBHOOKS_QUERY }
    let(:variables) { { demarcheNumber: procedure.id } }

    it 'lists the webhooks of the demarche' do
      expect(errors).to be_nil
      serialized = data[:webhooks].find { it[:id] == webhook.to_typed_id }
      expect(serialized[:url]).to eq(webhook.url)
      expect(serialized[:enabled]).to be(true)
    end

    context 'on a demarche of another administrateur' do
      let(:other_procedure) { create(:procedure, :new_administrateur) }
      let(:variables) { { demarcheNumber: other_procedure.id } }

      it { expect(errors).to be_present }
    end
  end

  describe 'webhook query' do
    let(:query) { WEBHOOK_QUERY }
    let(:variables) { { id: webhook.to_typed_id } }

    it 'returns the webhook' do
      expect(errors).to be_nil
      expect(data[:webhook][:id]).to eq(webhook.to_typed_id)
      expect(data[:webhook][:eventTypes]).to eq(webhook.event_types)
    end

    context 'with a token not authorized on the demarche' do
      let(:context) { { administrateur_id: admin.id, procedure_ids: [], write_access: true, remote_ip: '192.168.1.23' } }

      it { expect(errors).to be_present }
    end

    context 'on a discarded demarche' do
      before { procedure.discard! }

      it 'hides the webhook like the rest of the demarche' do
        expect(errors).to be_present
        expect(subject['data']).to be_nil
      end
    end
  end

  describe 'webhookCreer' do
    let(:query) { WEBHOOK_CREER_QUERY }
    let(:variables) { { demarcheNumber: procedure.id, url: "https://example.com/hook", eventTypes: ["dossier_depose"] } }

    it 'creates a webhook and returns the secret' do
      expect(errors).to be_nil

      payload = data[:webhookCreer]
      expect(payload[:errors]).to be_nil
      expect(payload[:secret]).to be_present
      expect(payload[:webhook][:url]).to eq("https://example.com/hook")

      created = Webhook.find(ApplicationRecord.id_from_typed_id(payload[:webhook][:id]))
      expect(created.secret).to eq(payload[:secret])
      expect(created.procedure).to eq(procedure)
    end

    context 'when the feature is disabled on the demarche' do
      before { Flipper.disable(:webhooks_api, procedure) }

      it { expect(data[:webhookCreer][:errors]).to be_present }
    end

    context 'with an invalid url' do
      let(:variables) { { demarcheNumber: procedure.id, url: "http://localhost/hook", eventTypes: ["dossier_depose"] } }

      it { expect(data[:webhookCreer][:errors]).to be_present }
    end

    context 'with a private ip url' do
      let(:variables) { { demarcheNumber: procedure.id, url: "http://192.168.1.1/hook", eventTypes: ["dossier_depose"] } }

      it 'returns a localized validation error' do
        expect(data[:webhookCreer][:errors].sole[:message]).to include("pointe vers une adresse IP privée")
      end
    end

    context 'with a read only token' do
      let(:context) { { administrateur_id: admin.id, procedure_ids: admin.procedure_ids, write_access: false, remote_ip: '192.168.1.23' } }

      it { expect(data[:webhookCreer][:errors]).to be_present }
    end

    context 'on a demarche of another administrateur' do
      let(:other_procedure) { create(:procedure, :new_administrateur) }
      let(:variables) { { demarcheNumber: other_procedure.id, url: "https://example.com/hook", eventTypes: ["dossier_depose"] } }

      it { expect(data[:webhookCreer][:errors]).to be_present }
    end
  end

  describe 'webhookModifier' do
    let(:query) { WEBHOOK_MODIFIER_QUERY }
    let(:variables) { { id: webhook.to_typed_id, eventTypes: ["message_cree"] } }

    it 'updates the webhook' do
      expect(data[:webhookModifier][:errors]).to be_nil
      expect(webhook.reload.event_types).to eq(["message_cree"])
    end

    context 'on a webhook of another administrateur' do
      let(:other_webhook) { Webhook.create!(procedure: create(:procedure, :new_administrateur), url: "https://exemple.fr/hook", event_types: ["dossier_depose"]) }
      let(:variables) { { id: other_webhook.to_typed_id, eventTypes: ["message_cree"] } }

      it 'hides the webhook behind a top-level error' do
        expect(errors).to be_present
        expect(data[:webhookModifier]).to be_nil
        expect(other_webhook.reload.event_types).to eq(["dossier_depose"])
      end
    end

    context 'while a delivery run is in flight' do
      before { webhook.update!(delivery_claimed_at: Time.current) }

      it 'invalidates the claim and hands the backlog to a fresh delivery job' do
        expect(data[:webhookModifier][:errors]).to be_nil
        expect(webhook.reload.delivery_claimed_at).to be_nil
        expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
      end
    end

    context 'with an explicitly empty eventTypes' do
      let(:variables) { { id: webhook.to_typed_id, eventTypes: [] } }

      it 'returns a validation error instead of silently ignoring it' do
        expect(data[:webhookModifier][:errors]).to be_present
        expect(webhook.reload.event_types).not_to be_empty
      end
    end
  end

  describe 'webhookSupprimer' do
    let(:query) { WEBHOOK_SUPPRIMER_QUERY }
    let(:variables) { { id: webhook.to_typed_id } }

    it 'deletes the webhook' do
      expect(data[:webhookSupprimer][:errors]).to be_nil
      expect(Webhook.exists?(webhook.id)).to be(false)
    end
  end

  describe 'webhookRenouvelerSecret' do
    let(:query) { WEBHOOK_RENOUVELER_SECRET_QUERY }
    let(:variables) { { id: webhook.to_typed_id } }

    it 'regenerates and returns the secret' do
      original_secret = webhook.secret

      payload = data[:webhookRenouvelerSecret]
      expect(payload[:errors]).to be_nil
      expect(payload[:secret]).to be_present
      expect(payload[:secret]).not_to eq(original_secret)
      expect(webhook.reload.secret).to eq(payload[:secret])
    end
  end

  describe 'webhookDesactiver' do
    let(:query) { WEBHOOK_DESACTIVER_QUERY }
    let(:variables) { { id: webhook.to_typed_id } }

    it 'disables the webhook' do
      expect(data[:webhookDesactiver][:errors]).to be_nil
      expect(webhook.reload.enabled).to be(false)
    end
  end

  describe 'webhookActiver' do
    let(:query) { WEBHOOK_ACTIVER_QUERY }
    let(:variables) { { id: webhook.to_typed_id } }

    it 're-enables an auto-disabled webhook with a catch-up delivery' do
      webhook.update!(enabled: false, auto_disabled_at: Time.current, consecutive_failures: 5, last_error: "HTTP 500", delivery_claimed_at: Time.current)

      expect(data[:webhookActiver][:errors]).to be_nil

      webhook.reload
      expect(webhook.enabled).to be(true)
      expect(webhook.auto_disabled_at).to be_nil
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_error).to be_nil
      expect(webhook.delivery_claimed_at).to be_nil
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'only re-enqueues a delivery when already enabled, leaving the claim alone' do
      claimed_at = Time.current.change(usec: 0)
      webhook.update!(delivery_claimed_at: claimed_at)

      expect(data[:webhookActiver][:errors]).to be_nil

      expect(webhook.reload.delivery_claimed_at).to eq(claimed_at)
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end

    it 'lifts the backoff of an enabled webhook so the catch-up delivery is immediate' do
      webhook.update!(consecutive_failures: 5, last_attempt_at: Time.current, last_error: "HTTP 500")

      expect(data[:webhookActiver][:errors]).to be_nil

      webhook.reload
      expect(webhook.in_backoff?).to be(false)
      expect(webhook.consecutive_failures).to eq(0)
      expect(webhook.last_error).to be_nil
      expect(Webhooks::DeliveryJob).to have_been_enqueued.with(webhook.id)
    end
  end

  describe 'feature flag gating' do
    let(:variables) { { id: webhook.to_typed_id } }

    before { Flipper.disable(:webhooks_api, procedure) }

    context 'webhookActiver' do
      let(:query) { WEBHOOK_ACTIVER_QUERY }

      it { expect(data[:webhookActiver][:errors]).to be_present }
    end

    context 'webhookModifier' do
      let(:query) { WEBHOOK_MODIFIER_QUERY }
      let(:variables) { { id: webhook.to_typed_id, eventTypes: ["message_cree"] } }

      it { expect(data[:webhookModifier][:errors]).to be_present }
    end

    context 'webhookRenouvelerSecret' do
      let(:query) { WEBHOOK_RENOUVELER_SECRET_QUERY }

      it { expect(data[:webhookRenouvelerSecret][:errors]).to be_present }
    end

    context 'webhookDesactiver stays available' do
      let(:query) { WEBHOOK_DESACTIVER_QUERY }

      it do
        expect(data[:webhookDesactiver][:errors]).to be_nil
        expect(webhook.reload.enabled).to be(false)
      end
    end

    context 'webhookSupprimer stays available' do
      let(:query) { WEBHOOK_SUPPRIMER_QUERY }

      it do
        expect(data[:webhookSupprimer][:errors]).to be_nil
        expect(Webhook.exists?(webhook.id)).to be(false)
      end
    end
  end

  WEBHOOKS_QUERY = <<-GRAPHQL
  query($demarcheNumber: Int!) {
    webhooks(demarche: { number: $demarcheNumber }) {
      id
      url
      enabled
    }
  }
  GRAPHQL

  WEBHOOK_QUERY = <<-GRAPHQL
  query($id: ID!) {
    webhook(id: $id) {
      id
      eventTypes
    }
  }
  GRAPHQL

  WEBHOOK_CREER_QUERY = <<-GRAPHQL
  mutation($demarcheNumber: Int!, $url: String!, $eventTypes: [WebhookEventTypeEnum!]!) {
    webhookCreer(input: { demarche: { number: $demarcheNumber }, url: $url, eventTypes: $eventTypes }) {
      webhook { id url }
      secret
      errors { message }
    }
  }
  GRAPHQL

  WEBHOOK_MODIFIER_QUERY = <<-GRAPHQL
  mutation($id: ID!, $eventTypes: [WebhookEventTypeEnum!]) {
    webhookModifier(input: { webhook: $id, eventTypes: $eventTypes }) {
      webhook { id eventTypes }
      errors { message }
    }
  }
  GRAPHQL

  WEBHOOK_SUPPRIMER_QUERY = <<-GRAPHQL
  mutation($id: ID!) {
    webhookSupprimer(input: { webhook: $id }) {
      id
      errors { message }
    }
  }
  GRAPHQL

  WEBHOOK_RENOUVELER_SECRET_QUERY = <<-GRAPHQL
  mutation($id: ID!) {
    webhookRenouvelerSecret(input: { webhook: $id }) {
      webhook { id }
      secret
      errors { message }
    }
  }
  GRAPHQL

  WEBHOOK_ACTIVER_QUERY = <<-GRAPHQL
  mutation($id: ID!) {
    webhookActiver(input: { webhook: $id }) {
      webhook { id enabled }
      errors { message }
    }
  }
  GRAPHQL

  WEBHOOK_DESACTIVER_QUERY = <<-GRAPHQL
  mutation($id: ID!) {
    webhookDesactiver(input: { webhook: $id }) {
      webhook { id enabled }
      errors { message }
    }
  }
  GRAPHQL
end
