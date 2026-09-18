# frozen_string_literal: true

module Ami
  class CreateNotificationService
    SOURCE = ApplicationHelper::APP_HOST

    ITEM_GENERIC_STATUS_BY_STATE = {
      brouillon: "new",
      en_construction: "wip",
      en_instruction: "wip",
      repasser_en_instruction: "wip",
      accepte: "closed",
      refuse: "closed",
      sans_suite: "closed",
    }.freeze

    attr_reader :dossier, :state, :trigger, :skip_consent_check

    def initialize(dossier:, trigger:, state:, skip_consent_check: false)
      @dossier = dossier
      @state = (state || dossier.state).to_sym
      @trigger = trigger.to_sym
      @skip_consent_check = skip_consent_check
    end

    # skip_consent_check: le consentement vient d'être accordé, le job n'a pas à le
    # revérifier avant d'envoyer.
    def self.call(dossier:, trigger: :dossier_state_change, state: nil, skip_consent_check: false)
      new(dossier:, trigger:, state:, skip_consent_check:).call
    end

    def call
      if !eligible?
        Rails.logger.debug { "AMI notification not eligible for dossier #{dossier.id}: #{not_eligible_reason}" }
        return
      end

      Rails.logger.debug { "AMI notification eligible for dossier #{dossier.id} (state: #{state})" }

      payload = create_notification_payload(event_date: Time.zone.now.iso8601)
      return if payload[:recipient_fc_hash].blank?

      Ami::SendNotificationJob.perform_later(payload, context, skip_consent_check:)
    end

    # Contrat de PUT /api/v2/event : event_date remplace send_date et
    # content_link remplace item_external_url.
    def create_notification_payload(event_date:)
      {
        recipient_fc_hash: RecipientFcHash.call(dossier.user),
        content_title:,
        content_body:,
        content_link: item_external_url,
        item_type: dossier.procedure.id.to_s,
        item_id: dossier.id.to_s,
        item_status_label:,
        item_generic_status:,
        item_canal: ApplicationHelper::APP_HOST,
        event_date:,
      }
    end

    private

    def item_external_url
      if messagerie_message?
        Rails.application.routes.url_helpers.messagerie_dossier_url(dossier)
      else
        Rails.application.routes.url_helpers.dossier_url(dossier)
      end
    end

    def eligible?
      not_eligible_reason.blank?
    end

    def not_eligible_reason
      return "missing AMI configuration" unless Ami::Client.new.configured?
      return ":ami_notifications feature flag disabled" unless dossier.procedure.feature_enabled?(:ami_notifications)
    end

    def content_title
      return APPLICATION_NAME
    end

    def content_body
      I18n.with_locale(dossier.user_locale) do
        if messagerie_message?
          I18n.t("dossier_mailer.notify_new_answer.subject", dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)
        elsif state == :brouillon
          I18n.t("dossier_mailer.notify_new_draft.subject", libelle_demarche: dossier.procedure.libelle)
        else
          dossier.email_template_for(email_template_state).subject_for_dossier(dossier)
        end
      end
    end

    def context
      {
        procedure: dossier.procedure.id,
        dossier: dossier.id,
        state:,
      }
    end

    def item_status_label
      user_state = state == :en_construction ? "depose" : dossier.state
      I18n.t("activerecord.attributes.dossier/state.#{user_state}")
    end

    def item_generic_status
      ITEM_GENERIC_STATUS_BY_STATE.fetch(state.to_sym, ITEM_GENERIC_STATUS_BY_STATE.fetch(state, "wip"))
    end

    def messagerie_message?
      trigger == :messagerie_message
    end

    def email_template_state
      if state == :repasser_en_instruction
        DossierOperationLog.operations.fetch(:repasser_en_instruction)
      else
        Dossier.states.fetch(state)
      end
    end
  end
end
