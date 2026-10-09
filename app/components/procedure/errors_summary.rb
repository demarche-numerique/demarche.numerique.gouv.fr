# frozen_string_literal: true

class Procedure::ErrorsSummary < ApplicationComponent
  ErrorDescriptor = Data.define(:anchor, :label, :error_message)

  EMAIL_TEMPLATE_ATTRIBUTES = [:email_depose, :email_passe_en_instruction, :email_accepte, :email_refuse, :email_classe_sans_suite, :email_repasse_en_instruction].freeze

  def initialize(procedure:, validation_context:)
    @procedure = procedure
    @validation_context = validation_context
  end

  def title
    case @validation_context
    when :private_type_de_champs_editor
      t(".private_annotations_contain_errors")
    when :public_type_de_champs_editor
      t(".form_fields_contain_errors")
    when :publication
      if @procedure.publiee?
        t(".problems_block_publishing_modifications")
      else
        t(".problems_block_publishing_procedure")
      end
    end
  end

  def invalid?
    @procedure.validate(@validation_context)
    @procedure.errors.present?
  end

  def errors
    @procedure.errors.flat_map { to_error_descriptors(_1) }
  end

  def error_correction_page(error)
    tdc = error.options[:type_de_champ]
    return tdc_correction_page(tdc) if tdc

    case error.attribute
    when :ineligibilite_rules
      edit_admin_procedure_ineligibilite_rules_path(@procedure)
    when :attestation_acceptation_template, :attestation_refus_template
      if error.detail[:value].version == 1
        edit_admin_procedure_attestation_template_path(@procedure)
      else
        edit_admin_procedure_attestation_template_v2_path(@procedure, attestation_kind: error.detail[:value].kind)
      end
    when *EMAIL_TEMPLATE_ATTRIBUTES
      klass = "Emails::#{error.attribute.to_s.delete_prefix('email_').camelize}".constantize
      edit_admin_procedure_email_template_path(@procedure, klass.const_get(:SLUG))
    end
  end

  def tdc_correction_page(tdc)
    anchor = dom_id(tdc, :editor_error)

    if tdc.private?
      annotations_admin_procedure_path(@procedure, anchor:)
    else
      champs_admin_procedure_path(@procedure, anchor:)
    end
  end

  def to_error_descriptors(error)
    template_errors = error.attribute.in?(EMAIL_TEMPLATE_ATTRIBUTES) ? error.detail[:value]&.errors : nil
    return [to_error_descriptor(error)] if template_errors.blank?

    anchor = error_correction_page(error)
    label = error.base.class.human_attribute_name(error.attribute)
    template_errors.map { ErrorDescriptor.new(anchor, label, _1.full_message) }
  end

  def to_error_descriptor(error)
    tdc = error.options[:type_de_champ]
    libelle = tdc ? tdc.libelle.truncate(200) : error.base.class.human_attribute_name(error.attribute)

    ErrorDescriptor.new(error_correction_page(error), libelle, error.message)
  end
end
