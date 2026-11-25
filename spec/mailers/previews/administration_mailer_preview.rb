# frozen_string_literal: true

class AdministrationMailerPreview < ActionMailer::Preview
  def invite_admin
    AdministrationMailer.invite_admin(administrateur, "12345678")
  end

  def invite_admin_whose_already_has_an_account
    AdministrationMailer.invite_admin(administrateur, nil)
  end

  def invite_admin_via_pro_connect
    AdministrationMailer.invite_admin_via_pro_connect(administrateur)
  end

  private

  def procedure_1
    Procedure.new(id: 10, libelle: "Démarche des marches", administrateurs: [administrateur])
  end

  def procedure_2
    Procedure.new(id: 20, libelle: "Démarche pieds", administrateurs: [administrateur])
  end

  def administrateur
    Administrateur.new(id: 111, user: User.new(email: "chef.de.service@administration.gouv.fr"))
  end
end
