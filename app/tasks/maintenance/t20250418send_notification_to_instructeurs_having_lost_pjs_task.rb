# frozen_string_literal: true

module Maintenance
  class T20250418sendNotificationToInstructeursHavingLostPjsTask < MaintenanceTasks::Task
    # Documentation: informe par adresse électronique les instructeurs dont des PJ
    # ont été perdues suite à un bug introduit dans la release 2025-03-11-01
    # avec le storage OpenStack.

    # include RunnableOnDeployConcern
    include StatementsHelpersConcern

    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::SanitizeHelper
    include Rails.application.routes.url_helpers

    # Vous devez définir host par défaut pour les URL absolues
    default_url_options[:host] = APPLICATION_BASE_URL

    def collection
      TaskLog.where("data->>'state' = ?", 'definitely lost')
        .where("data ? 'procedure_id'")
        .pluck(Arel.sql("data->>'procedure_id'"))
        .uniq
        .sort
    end

    def process(procedure_id)
      task_logs = TaskLog.where("data->>'state' = ?", 'definitely lost')
        .where("data->>'procedure_id' = ?", procedure_id.to_s)
        .where.not("data ? 'instructeur_notified'")

      return if task_logs.empty?

      blob_keys = task_logs.map { it.data["blob_key"] }

      blob_champ_pjs = ActiveStorage::Blob.includes(:attachments).where(key: blob_keys)
        .filter { it.attachments.first&.record_type == 'Champ' && it.attachments.first&.record&.public? }
        .flat_map { |blob| blob.attachments.map { |att| [blob, att.record] } }

      champ_pjs = blob_champ_pjs.map(&:second).uniq.sort_by(&:id)

      dossier_id_champs = champ_pjs.group_by(&:dossier_id)

      en_instruction = Dossier.visible_by_administration.en_instruction.where(id: dossier_id_champs.keys)

      puts "en_instruction: #{Dossier.all.inspect}"
      puts "en_instruction: #{en_instruction.inspect}"

      # On envoie un mail à chaque premier instructeur qui suit le dossier (?)
      en_instruction.group_by { it.followers_instructeurs.first&.email }.each do |to, dossiers|
        next if to.nil?

        dossiers_and_champs = dossiers.map { |dossier| [dossier, dossier_id_champs[dossier.id]] }
        send_mail(to:, body: instructeur_body_email(dossiers_and_champs))
      end

      task_logs.update_all(%(data = jsonb_set(data, '{instructeur_notified}', '"true"')))
    end

    def send_mail(to:, body:)
      subject = "[#{APPLICATION_NAME}] Action requise : pièces jointes manquantes"
      title = "Pièces jointes manquantes"
      BlankMailer.send_template(to:, subject:, title:, body:).deliver_later
    end

    def instructeur_body_email(dossiers_and_champs)
      <<~TEXT
        Bonjour,<br><br>

        En raison d’une erreur technique, les pièces jointes des dossiers suivants ne sont plus disponibles :

        #{to_html_list(list_of_missing_pjs_and_dossier(dossiers_and_champs, link_for: :instructeur))}

        Si ces pièces sont toujours nécessaires au traitement du dossier, pourriez-vous recontacter les usagers par la messagerie pour leur demander de les retransmettre ?<br><br>

        Nous restons à votre disposition pour toute question sur #{CONTACT_EMAIL} .<br><br>

        Nous vous prions de nous excuser pour la gêne occasionnée par cet incident.
      TEXT
    end

    def list_of_missing_pjs_and_dossier(dossiers_and_champs, link_for:)
      dossiers_and_champs.map do |dossier, champs|
        url = if link_for == :user
          Rails.application.routes.url_helpers.dossier_url(dossier)
        else
          Rails.application.routes.url_helpers.instructeur_dossier_url(dossier.procedure.id, dossier)
        end

        dossier_link = tag.a("dossier n° #{number_with_delimiter(dossier.id)}", href: url)
        "#{safe_champs_libelles(champs).join(', ')} du #{dossier_link} sur la démarche #{dossier.procedure.libelle}"
      end
    end

    def safe_champs_libelles(champs)
      champs.filter_map do |champ|
        begin
          champ.libelle
        rescue
          # Ignore error like Type De Champ 3990816 not found in Revision 168536
        end
      end
    end

    def to_html_list(messages)
      messages
        .map { |message| tag.li(sanitize(message, scrubber: Sanitizers::MailScrubber.new)) }
        .then { |lis| tag.ul(lis.reduce(&:+)) }
    end
  end
end
