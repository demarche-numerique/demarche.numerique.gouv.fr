# frozen_string_literal: true

class InstructeurMailerPreview < ActionMailer::Preview
  def last_week_overview
    InstructeurMailer.last_week_overview(Instructeur.first)
  end

  def send_dossier
    InstructeurMailer.send_dossier(instructeur, Dossier.new(id: 10, procedure: procedure), target_instructeur)
  end

  def send_login_token
    InstructeurMailer.send_login_token(instructeur, "token")
  end

  def trusted_device_token_renewal
    InstructeurMailer.trusted_device_token_renewal(instructeur, "renewal_token", 1.week.from_now)
  end

  def send_notifications
    data = [
      {
        procedure_libelle: 'une superbe démarche',
        procedure_id: 213,
        nb_en_construction: 2,
        nb_en_instruction: 2,
        nb_processed: 5,
        nb_accepted: 1,
        nb_refused: 2,
        nb_closed_without_continuation: 2,
        nb_dossiers_with_notifications: 2,
        nb_notifications: { "annotation_instructeur" => 1, "dossier_modifie" => 1 },
      },
      {
        procedure_libelle: 'une démarche incroyable',
        procedure_id: 213,
        nb_en_construction: 1,
        nb_en_instruction: 2,
        nb_processed: 5,
        nb_accepted: 1,
        nb_refused: 2,
        nb_closed_without_continuation: 2,
        nb_dossiers_with_notifications: 1,
        nb_notifications: { "annotation_instructeur" => 1, "dossier_modifie" => 1 },
      },
    ]
    InstructeurMailer.send_notifications(instructeur, data)
  end

  private

  def instructeur
    Instructeur.new(
      id: 10,
      user: User.new(email: 'instructeur@administration.gouv.fr')
    )
  end

  def target_instructeur
    Instructeur.new(
      id: 12,
      user: User.new(email: 'collegue@administration.gouv.fr')
    )
  end

  def procedure
    Procedure.new(id: 15, libelle: 'libelle')
  end

  def dossier
    Dossier.new(id: 15, procedure: procedure)
  end
end
