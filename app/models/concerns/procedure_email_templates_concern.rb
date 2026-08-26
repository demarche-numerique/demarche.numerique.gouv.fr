# frozen_string_literal: true

module ProcedureEmailTemplatesConcern
  extend ActiveSupport::Concern

  included do
    has_many :custom_email_templates, class_name: "EmailTemplate", dependent: :destroy
    has_one :email_depose, class_name: "Emails::Depose", dependent: :destroy
    has_one :email_passe_en_instruction, class_name: "Emails::PasseEnInstruction", dependent: :destroy
    has_one :email_accepte, class_name: "Emails::Accepte", dependent: :destroy
    has_one :email_refuse, class_name: "Emails::Refuse", dependent: :destroy
    has_one :email_classe_sans_suite, class_name: "Emails::ClasseSansSuite", dependent: :destroy
    has_one :email_repasse_en_instruction, class_name: "Emails::RepasseEnInstruction", dependent: :destroy

    validates_associated :email_depose, on: :publication
    validates_associated :email_passe_en_instruction, on: :publication
    validates_associated :email_accepte, on: :publication
    validates_associated :email_refuse, on: :publication
    validates_associated :email_classe_sans_suite, on: :publication
    validates_associated :email_repasse_en_instruction, on: :publication
  end

  def send_combined_declarative_email?
    declarative? && combined_declarative_email?
  end

  def email_depose_or_default
    email_depose || Emails::Depose.default_for_procedure(self)
  end

  def email_passe_en_instruction_or_default
    email_passe_en_instruction || Emails::PasseEnInstruction.default_for_procedure(self)
  end

  def email_accepte_or_default
    email_accepte || Emails::Accepte.default_for_procedure(self)
  end

  def email_refuse_or_default
    email_refuse || Emails::Refuse.default_for_procedure(self)
  end

  def email_classe_sans_suite_or_default
    email_classe_sans_suite || Emails::ClasseSansSuite.default_for_procedure(self)
  end

  def email_repasse_en_instruction_or_default
    email_repasse_en_instruction || Emails::RepasseEnInstruction.default_for_procedure(self)
  end

  def email_template_for(state)
    case state
    when Dossier.states.fetch(:en_construction)
      email_depose_or_default
    when Dossier.states.fetch(:en_instruction)
      email_passe_en_instruction_or_default
    when DossierOperationLog.operations.fetch(:repasser_en_instruction)
      email_repasse_en_instruction_or_default
    when Dossier.states.fetch(:accepte)
      email_accepte_or_default
    when Dossier.states.fetch(:refuse)
      email_refuse_or_default
    when Dossier.states.fetch(:sans_suite)
      email_classe_sans_suite_or_default
    else
      raise "Unknown dossier state: #{state}"
    end
  end

  def email_templates
    [
      email_depose_or_default,
      email_passe_en_instruction_or_default,
      email_accepte_or_default,
      email_refuse_or_default,
      email_classe_sans_suite_or_default,
      email_repasse_en_instruction_or_default,
    ]
  end

  def email_template_attestation_inconsistency_state(email_type)
    case email_type
    when :acceptation
      email = email_accepte
      attestation = attestation_acceptation_template
    when :refus
      email = email_refuse
      attestation = attestation_refus_template
    end

    return if email.nil?

    tag_present = email.body.to_s.include?('--lien attestation--')
    if attestation&.activated? && !tag_present
      :missing_tag
    elsif !attestation&.activated? && tag_present
      :extraneous_tag
    end
  end
end
