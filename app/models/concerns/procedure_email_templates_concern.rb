# frozen_string_literal: true

module ProcedureEmailTemplatesConcern
  extend ActiveSupport::Concern

  ATTESTATION_TAG = '--lien attestation--'

  included do
    has_many :custom_email_templates, class_name: "EmailTemplate", dependent: :destroy
    # validate: false — la validation passe uniquement par le
    # validates_associated ci-dessous, sur le modèle du réglage courant.
    has_many :email_depose_templates, -> { where(type: Emails::DEPOSE_TYPES) }, class_name: "EmailTemplate", inverse_of: :procedure, dependent: :destroy, validate: false
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

    before_update :reset_email_templates_on_declarative_change
  end

  def send_combined_declarative_email?
    declarative? && combined_declarative_email?
  end

  def depose_email_class
    if !send_combined_declarative_email?
      Emails::Depose
    elsif declarative_accepte?
      Emails::DeposeEtAccepte
    else
      Emails::DeposeEtPasseEnInstruction
    end
  end

  def email_depose
    email_depose_templates.find { it.type == depose_email_class.name }
  end

  def email_depose=(email_template)
    email_depose_templates.replace([email_template].compact)
  end

  def email_depose_or_default
    email_depose || depose_email_class.default_for_procedure(self)
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

  # The cards follow the order in which an usager can receive the emails: the
  # combined email carries the passage en instruction, which moves last, and in
  # décla-accepté a réexamen is the only way back to a decision.
  def email_templates
    depose = email_depose_or_default
    decisions = [email_accepte_or_default, email_refuse_or_default, email_classe_sans_suite_or_default]
    passe = email_passe_en_instruction_or_default
    repasse = email_repasse_en_instruction_or_default

    if !send_combined_declarative_email?
      [depose, passe, *decisions, repasse]
    elsif declarative_accepte?
      [depose, repasse, *decisions, passe]
    else
      [depose, *decisions, repasse, passe]
    end
  end

  # Which set of card descriptions the admin screen must serve.
  def email_templates_context
    if !send_combined_declarative_email?
      :default
    elsif declarative_accepte?
      :accepte
    else
      :en_instruction
    end
  end

  # The kind of inconsistency to report, and the email template to send the
  # admin to, or nil when every template agrees with the attestation setting.
  def attestation_tag_inconsistency(email_type)
    emails, attestation = attestation_inconsistency_scope(email_type)
    expected_tag = attestation&.activated? || false

    inconsistent = emails.find { it.body.to_s.include?(ATTESTATION_TAG) != expected_tag }
    return if inconsistent.nil?

    { email_slug: inconsistent.class.const_get(:SLUG), kind: expected_tag ? :missing_tag : :extraneous_tag }
  end

  private

  # Only the depose template is tied to the setting, through its STI type: the
  # customized row would never be read again. The five others keep their type and
  # their triggers, so they survive the change.
  def reset_email_templates_on_declarative_change
    return if !declarative_with_state_changed?

    email_depose_templates.destroy_all
    self.combined_declarative_email = true
  end

  # In décla-accepté the combined email is the one announcing the acceptation,
  # Emails::Accepte only serving after a réexamen: both carry the attestation tag.
  def custom_email_depose_et_accepte
    email_depose if depose_email_class == Emails::DeposeEtAccepte
  end

  def attestation_inconsistency_scope(email_type)
    case email_type
    when :acceptation
      [[email_accepte, custom_email_depose_et_accepte].compact, attestation_acceptation_template]
    when :refus
      [[email_refuse].compact, attestation_refus_template]
    end
  end
end
