# frozen_string_literal: true

class Procedure::EmailTemplateCardComponent < ApplicationComponent
  def initialize(email_template:)
    @email_template = email_template
  end

  private

  def title
    @email_template.class.const_get(:DISPLAYED_NAME)
  end

  def desc
    @email_template.subject if edited?
  end

  def error
    @email_template.errors.full_messages.first if @email_template.errors.present?
  end

  def tag
    if edited?
      "modifié le #{DateFormatHelper.short(@email_template.updated_at)}"
    else
      "Modèle standard"
    end
  end

  def edited?
    @email_template.updated_at.present?
  end

  def edit_path
    edit_admin_procedure_mail_template_path(@email_template.procedure, @email_template.class.const_get(:SLUG))
  end

  def final_decision_templates
    [Mails::WithoutContinuationMail.const_get(:SLUG), Mails::RefusedMail.const_get(:SLUG), Mails::ClosedMail.const_get(:SLUG)]
  end

  def not_editable?
    @email_template.procedure.accuse_lecture? && final_decision_templates.include?(@email_template.class.const_get(:SLUG))
  end
end
