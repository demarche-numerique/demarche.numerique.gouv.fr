# frozen_string_literal: true

class ExpertMailer < ApplicationMailer
  layout 'mailers/layout'

  # TODO: replace with v2 after MEP
  def send_dossier_decision(avis_id)
    @avis = Avis.eager_load(:dossier).find(avis_id)
    @dossier = @avis.dossier
    email = @avis.expert.email
    @decision = decision_dossier(@dossier)
    subject = default_i18n_subject(id: @dossier.id, decision: @decision, libelle: @dossier.procedure.libelle)

    mail(to: email, subject: subject)
  end

  def send_dossier_decision_v2(avis)
    @avis = avis
    @dossier = @avis.dossier
    email = @avis.expert.email
    @decision = decision_dossier(@dossier)
    subject = I18n.t("expert_mailer.send_dossier_decision.subject", id: @dossier.id, decision: @decision, libelle: @dossier.procedure.libelle)

    mail(template_name: 'send_dossier_decision', to: email, subject: subject)
  end

  def self.critical_email?(action_name)
    false
  end
end

def decision_dossier(dossier)
  if dossier.accepte?
    I18n.t("expert_mailer.send_dossier_decision.decision.accepte")
  elsif dossier.sans_suite?
    I18n.t("expert_mailer.send_dossier_decision.decision.sans_suite")
  elsif dossier.refuse?
    I18n.t("expert_mailer.send_dossier_decision.decision.refuse")
  end
end
