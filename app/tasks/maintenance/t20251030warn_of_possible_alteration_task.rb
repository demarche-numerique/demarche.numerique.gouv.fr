# frozen_string_literal: true

module Maintenance
  class T20251030warnOfPossibleAlterationTask < MaintenanceTasks::Task
    # Tache pour notifier les instructeurs d’une altération des dossiers entre le 22 et 31 octobre 2025

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    csv_collection

    def process(row)
      dossier = Dossier.find_by(id: row["dossier_id"].to_i)
      return if dossier.nil?

      body = <<~HTML
        <p>Bonjour,</p>
        <p>Une anomalie technique a affecté ce dossier entre le 22 et 31 octobre 2025. Pendant cette période, une partie du dossier a pu avoir été altérée.</p>
        <p>Le problème a été corrigé et le dossier a retrouvé son état normal à l’exception des éventuels champs SIRET dont le recouvrement sera terminé le mardi 4 novembre à midi.</p>
        <p>Veuillez nous excuser pour la gêne occasionnée,<br>Cordialement,<br>L’équipe technique de #{APPLICATION_NAME}</p>
      HTML

      CommentaireService.create!(CONTACT_EMAIL, dossier, body:)
      DossierNotification.create_notification(dossier, :message)
    end
  end
end
