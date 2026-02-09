# frozen_string_literal: true

module Crisp
  class UserDataBuilder
    MAX_VALUE_LENGTH = 200

    def initialize(user)
      @user = user
      @instructeur = user.instructeur
      @administrateur = user.administrateur
    end

    def build_data
      data = {
        "Compte" => build_properties,
        **build_links,
        **build_notifications_data,
      }

      truncate_values(data)
    end

    private

    attr_reader :user, :instructeur, :administrateur

    def build_links
      links = {}
      links["ManagerUser"] = "#{user_link}\n#{email_link}"
      links["ManagerInstructeur"] = instructeur_link if instructeur.present?
      links["ManagerAdmin"] = administrateur_link if administrateur.present?

      links
    end

    def build_notifications_data
      return {} if instructeur.blank?

      enabled_ids, disabled_ids = partition_procedure_notifications

      data = {}
      if enabled_ids.any?
        data["NotifsActivees"] = "**Activées** sur démarche n° #{enabled_ids.map(&:to_s).join(", ")}"
      end

      if disabled_ids.any?
        data["NotifsDesactivees"] = "**Désactivées** sur démarche n° #{disabled_ids.map(&:to_s).join(", ")}"
      end

      data
    end

    def build_properties
      text = []
      text << if user.email_verified_at?
        "**Adresse électronique vérifiée**"
      else
        "⚠️ **Adresse électronique non vérifiée**"
      end

      text << "❌ Compte bloqué depuis le #{DateFormatHelper.short(user.blocked_at)}" if user.blocked_at.present?

      text.join("\n")
    end

    def partition_procedure_notifications
      enabled = []
      disabled = []

      return [enabled, disabled] if instructeur.blank?

      ips_by_procedure_id = InstructeursProcedure
        .where(instructeur:)
        .index_by(&:procedure_id)

      instructeur.procedure_ids.each do |procedure_id|
        ip = ips_by_procedure_id[procedure_id]

        if notifications_disabled?(ip)
          disabled << procedure_id
        else
          enabled << procedure_id
        end
      end

      [enabled.sort, disabled.sort]
    end

    def notifications_disabled?(ip)
      !ip&.instant_email_new_dossier ||
        !ip&.instant_email_new_message ||
        !ip&.instant_email_new_expert_avis
    end

    def user_link
      "[#{user.model_name.human} ##{user.id}](#{manager_user_url})"
    end

    def instructeur_link
      "[#{instructeur.model_name.human} ##{instructeur.id}](#{manager_instructeur_url})"
    end

    def administrateur_link
      "[#{administrateur.model_name.human} ##{administrateur.id}](#{manager_administrateur_url})"
    end

    def email_link
      "[Emails envoyés](#{emails_manager_user_url})"
    end

    def manager_user_url
      Rails.application.routes.url_helpers.manager_user_url(user, host:)
    end

    def manager_instructeur_url
      Rails.application.routes.url_helpers.manager_instructeur_url(instructeur, host:)
    end

    def manager_administrateur_url
      Rails.application.routes.url_helpers.manager_administrateur_url(administrateur, host:)
    end

    def emails_manager_user_url
      Rails.application.routes.url_helpers.emails_manager_user_url(user, host:)
    end

    def truncate_values(data)
      data.transform_values { it.truncate(MAX_VALUE_LENGTH, omission: "…", separator: /\s+/) }
    end

    def host = ENV["APP_HOST"]
  end
end
