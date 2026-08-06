# frozen_string_literal: true

class Dossiers::ErrorsFullMessagesComponent < ApplicationComponent
  ErrorDescriptor = Data.define(:anchor, :label, :error_message)

  def initialize(dossier:)
    @dossier = dossier
  end

  def dedup_errors
    @dedup_errors ||= @dossier.errors
      .to_enum # ActiveModel::Errors.to_a is an alias to full_messages, we don't want that
      .to_a # but enum.to_a gives back an array
      .group_by { it.is_a?(ActiveModel::NestedError) ? it.inner_error.base : it.base }
      .flat_map do |_champ_instance, errors|
        errors = errors.reject { it.type == :missing } if errors.size > 1 # do not report missing when another exists
        errors.map { to_error_descriptor(_1) }
      end
  end

  def to_error_descriptor(error)
    model = error.is_a?(ActiveModel::NestedError) ? error.inner_error.base : error.base
    if model.respond_to?(:libelle) # a Champ or something acting as a Champ
      unested_attribute_name = error.attribute.to_s.split('.').last
      ErrorDescriptor.new("##{model.focusable_input_id(unested_attribute_name)}", model_libelle(model), error.message)
    else
      ErrorDescriptor.new("##{model.model_name.singular}_#{error.attribute}", model.class.human_attribute_name(error.attribute), error.message)
    end
  end

  def model_libelle(model)
    libelle = model.try(:libelle_for_error) || model.libelle
    parent_prefix(model) + row_number_prefix(model) + libelle.truncate(200)
  end

  def parent_prefix(model)
    return "" if !model.child?

    "#{[is_in_fieldset?(model) ? "[#{row_number(model)}]" : nil, model.parent.libelle].compact.join(" ")} - "
  end

  def row_number_prefix(model)
    return "" if !model.child? || is_in_fieldset?(model)

    "[#{row_number(model)}] "
  end

  def row_number(model)
    return 1 if !model.child?

    model.dossier.repetition_row_ids(model.parent).index(model.row_id) + 1
  end

  def is_in_fieldset?(model)
    return 0 if !model.child?

    model.parent.flat_children.size > 1
  end

  def render?
    !@dossier.errors.empty?
  end
end
