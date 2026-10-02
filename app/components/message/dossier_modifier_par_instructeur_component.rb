# frozen_string_literal: true

class Message::DossierModifierParInstructeurComponent < ApplicationComponent
  attr_reader :changed_columns, :dossier

  def initialize(dossier:, changed_columns:, motivation: nil)
    @dossier = dossier
    @changed_columns = changed_columns
    @motivation = motivation
  end

  def motivation
    return if @motivation.blank?

    sanitize(@motivation, scrubber: Sanitizers::MailScrubber.new)
  end

  def dossier_number
    @dossier.id
  end

  def demarche_title
    @dossier.procedure.libelle
  end

  def service_name
    @dossier.service_or_contact_information.nom
  end

  def self.render(dossier:, changed_columns:, motivation: nil)
    # Sanitize the rendered body before it is persisted as a commentaire: this
    # strips Rails' `annotate_rendered_view_with_filenames` HTML comments (enabled
    # in development) and keeps only the markup allowed in messages.
    body = ApplicationController.render(new(dossier:, changed_columns:, motivation:), layout: false)
    ApplicationController.helpers.sanitize(body, scrubber: Sanitizers::MailScrubber.new)
  end

  def self.preview(dossier)
    render(dossier:, changed_columns: dossier.instructeur_changed_columns)
  end

  def self.create_commentaire(traitement)
    body = render(dossier: traitement.dossier, changed_columns: traitement.changed_columns, motivation: traitement.motivation)
    CommentaireService.create!(traitement.instructeur, traitement.dossier, body:, deletable: false, dossier_modifie_par_instructeur: true)
  end
end
