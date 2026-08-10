# frozen_string_literal: true

class Procedure::ErrorsSummary < ApplicationComponent
  ErrorDescriptor = Data.define(:anchor, :label, :error_message)

  def initialize(procedure:, validation_context:)
    @procedure = procedure
    @validation_context = validation_context
  end

  def title
    case @validation_context
    when :private_types_de_champ_editor
      "Les annotations privées contiennent des erreurs"
    when :public_types_de_champ_editor
      "Les champs du formulaire contiennent des erreurs"
    when :publication
      if @procedure.publiee?
        "Des problèmes empêchent la publication des modifications"
      else
        "Des problèmes empêchent la publication de la démarche"
      end
    end
  end

  def invalid?
    @procedure.validate(@validation_context)
    @procedure.errors.present?
  end

  def errors
    @procedure.errors.map { to_error_descriptor(_1) }
  end

  def error_correction_page(error)
    case error.attribute
    when :ineligibilite_rules
      edit_admin_procedure_ineligibilite_rules_path(@procedure)
    when :draft_public_types_de_champ
      tdc = error.options[:type_de_champ]
      champs_admin_procedure_path(@procedure, anchor: dom_id(tdc.stable_self, :editor_error))
    when :draft_private_types_de_champ
      tdc = error.options[:type_de_champ]
      annotations_admin_procedure_path(@procedure, anchor: dom_id(tdc.stable_self, :editor_error))
    when :attestation_acceptation_template, :attestation_refus_template
      if error.detail[:value].version == 1
        edit_admin_procedure_attestation_template_path(@procedure)
      else
        edit_admin_procedure_attestation_template_v2_path(@procedure, attestation_kind: error.detail[:value].kind)
      end
    when :initiated_mail, :received_mail, :closed_mail, :refused_mail, :without_continuation_mail, :re_instructed_mail
      klass = "Mails::#{error.attribute.to_s.classify}".constantize
      edit_admin_procedure_mail_template_path(@procedure, klass.const_get(:SLUG))
    end
  end

  def to_error_descriptor(error)
    libelle = case error.attribute
    when :draft_public_types_de_champ, :draft_private_types_de_champ
      error.options[:type_de_champ].libelle.truncate(200)
    else
      error.base.class.human_attribute_name(error.attribute)
    end
    ErrorDescriptor.new(error_correction_page(error), libelle, error.message)
  end
end
