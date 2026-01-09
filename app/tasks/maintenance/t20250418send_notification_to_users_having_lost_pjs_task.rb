# frozen_string_literal: true

module Maintenance
  class T20250418sendNotificationToUsersHavingLostPjsTask < MaintenanceTasks::Task
    # Documentation: informe par adresse électronique les usagers et instructeurs dont des PJ
    # ont été perdues suite à un bug introduit dans la release 2025-03-11-01
    # avec le storage OpenStack.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::SanitizeHelper
    include Rails.application.routes.url_helpers
    include DossierHelper

    # Vous devez définir host par défaut pour les URL absolues
    default_url_options[:host] = APPLICATION_BASE_URL

    def collection
      TaskLog.where("data->>'state' = ?", 'definitely lost')
        .where("data ? 'email'")
        .pluck(Arel.sql("data->>'email'"))
        .uniq
        .sort
    end

    def process(email)
      task_logs = TaskLog.where("data->>'state' = ?", 'definitely lost')
        .where("data->>'email' = ?", email)
        .where.not("data ? 'notified'")

      return if task_logs.empty?

      blob_keys = task_logs.map { it.data["blob_key"] }

      blob_champ_pjs = ActiveStorage::Blob.includes(:attachments).where(key: blob_keys)
        .filter { it.attachments.first&.record_type == 'Champ' && it.attachments.first&.record&.public? }
        .flat_map { |blob| blob.attachments.map { |att| [blob, att.record] } }

      champ_pjs = blob_champ_pjs.map(&:second).uniq.sort_by(&:id)

      dossier_id_champs = champ_pjs.group_by(&:dossier_id)

      brouillon_or_en_construction = Dossier.visible_by_user.includes(:user).where(id: dossier_id_champs.keys, state: %w[brouillon en_construction])
      brouillon_or_en_construction.group_by { it.user.email }.each do |to, dossiers|
        dossiers_and_champs = dossiers.map { |dossier| [dossier, dossier_id_champs[dossier.id]] }
        send_mail(to:, body: user_body_email(to, dossiers_and_champs))
      end

      task_logs.update_all(%(data = jsonb_set(data, '{notified}', '"user"')))
    end

    def send_mail(to:, body:)
      subject = "[#{APPLICATION_NAME}] Action requise : pièces jointes manquantes"
      title = "Pièces jointes manquantes"
      BlankMailer.send_template(to:, subject:, title:, body:).deliver_later
    end

    def user_body_email(to, dossiers_and_champs)
      dossiers_by_state = dossiers_and_champs.group_by { |dossier, _| dossier.state }

      <<~TEXT
        Bonjour,<br><br>

        En raison d’une erreur technique, les pièces jointes suivantes ne sont plus disponibles :

        #{to_html_list(format_missing_files(dossiers_and_champs), style: "margin-bottom: 0.5rem")}

        <br><br>

        Nous vous invitons à joindre à nouveau ce(s) fichier(s) en suivant les instructions suivantes,
        même si un aperçu de la pièce jointe apparaît encore dans votre dossier :<br><br>

        #{format_instructions(dossiers_by_state)}

        <br><br>

        Nous restons à votre disposition pour toute question sur #{CONTACT_EMAIL} et vous prions
        de nous excuser pour la gêne occasionnée par cet incident.
      TEXT
    end

    private

    def format_missing_files(dossiers_and_champs)
      dossiers_and_champs.map do |dossier, champs|
        url = Rails.application.routes.url_helpers.dossier_url(dossier)
        dossier_link = tag.a("Dossier n° #{number_with_delimiter(dossier.id)}", href: url)

        html = "#{dossier_link} (#{dossier_display_state(dossier.state, lower: true)}) - #{dossier.procedure.libelle} : "

        if champs.size == 1
          begin
            html += champs.first.libelle
          rescue
            # Ignore error like Type De Champ 3990816 not found in Revision 168536
            html = "#{dossier_link} (#{dossier_display_state(dossier.state, lower: true)}) - #{dossier.procedure.libelle}"
          end
        else
          html += to_html_list(safe_champs_libelles(champs))
        end

        html
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

    def format_instructions(dossiers_by_state)
      instructions = []

      if dossiers_by_state['brouillon'].present?
        instructions << <<~TEXT
          <u>Pour un dossier en brouillon :</u>
          <ul>
            <li>Pour chaque pièce jointe, cliquez sur la corbeille puis réenvoyez votre document</li>
            <li>Déposez votre dossier quand vous le souhaitez</li>
          </ul>
        TEXT
      end

      if dossiers_by_state['en_construction'].present?
        instructions << <<~TEXT
          <u>Pour un dossier en construction :</u>
          <ul>
            <li>Cliquez sur <em>Modifier mon dossier</em></li>
            <li>Pour chaque pièce jointe, cliquez sur la corbeille puis réenvoyez votre document</li>
            <li>Cliquez sur <em>Déposer les modifications</em> pour redéposer le dossier</li>
          </ul>
        TEXT
      end

      instructions.join("<br>")
    end

    def to_html_list(messages, style: nil)
      messages
        .map { |message| tag.li(sanitize(message, scrubber: Sanitizers::MailScrubber.new), style:) }
        .then { |lis| tag.ul(lis.reduce(&:+)) }
    end
  end
end
