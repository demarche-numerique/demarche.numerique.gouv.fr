# frozen_string_literal: true

class TypesDeChamp::Prefill < SimpleDelegator
  include ActionView::Helpers::UrlHelper
  include ApplicationHelper

  POSSIBLE_VALUES_THRESHOLD = 5

  def initialize(type_de_champ, revision)
    super(type_de_champ)
    @revision = revision
  end

  def self.build(type_de_champ, revision)
    case type_de_champ
    when TypesDeChamp::DropDownList
      TypesDeChamp::PrefillDropDownList.new(type_de_champ, revision)
    when TypesDeChamp::MultipleDropDownList
      TypesDeChamp::PrefillMultipleDropDownList.new(type_de_champ, revision)
    when TypesDeChamp::Pays, TypesDeChamp::Region, TypesDeChamp::Departement
      TypesDeChamp::PrefillGeo.new(type_de_champ, revision)
    when TypesDeChamp::Repetition
      TypesDeChamp::PrefillRepetition.new(type_de_champ, revision)
    when TypesDeChamp::Commune
      TypesDeChamp::PrefillCommune.new(type_de_champ, revision)
    when TypesDeChamp::Address
      TypesDeChamp::PrefillAddress.new(type_de_champ, revision)
    when TypesDeChamp::Epci
      TypesDeChamp::PrefillEpci.new(type_de_champ, revision)
    when TypesDeChamp::Formatted
      TypesDeChamp::PrefillFormatted.new(type_de_champ, revision)
    when TypesDeChamp::Siret
      TypesDeChamp::PrefillSiret.new(type_de_champ, revision)
    when TypesDeChamp::Referentiel
      TypesDeChamp::PrefillReferentiel.new(type_de_champ, revision)
    when TypesDeChamp::PreRempli
      TypesDeChamp::PrefillPreRempli.new(type_de_champ, revision)
    when TypesDeChamp::Date, TypesDeChamp::Datetime
      TypesDeChamp::PrefillDate.new(type_de_champ, revision)
    when TypesDeChamp::IntegerNumber, TypesDeChamp::DecimalNumber
      TypesDeChamp::PrefillNumber.new(type_de_champ, revision)
    when TypesDeChamp::Civilite
      TypesDeChamp::PrefillCivilite.new(type_de_champ, revision)
    when TypesDeChamp::YesNo, TypesDeChamp::Checkbox
      TypesDeChamp::PrefillBoolean.new(type_de_champ, revision)
    when TypesDeChamp::DossierLink
      TypesDeChamp::PrefillDossierLink.new(type_de_champ, revision)
    else
      new(type_de_champ, revision)
    end
  end

  def self.wrap(collection, revision)
    collection.map { |type_de_champ| build(type_de_champ, revision) }
  end

  def possible_values
    values = []
    values << description if description.present?
    if too_many_possible_values?
      values << link_to_all_possible_values
    else
      values << to_sentence(all_possible_values)
    end
    safe_join(values.compact, tag.br)
  end

  def all_possible_values
    []
  end

  def example_value
    return nil unless prefillable?

    I18n.t("views.prefill_descriptions.edit.examples.#{type_champ}")
  end

  # Screens a raw prefill input and returns the assignable attributes, or nil
  # when the input must be rejected (the champ is then not prefilled at all).
  # Subclasses screening a single value override screened_value to return the
  # normalized value or nil; subclasses assigning several attributes override
  # this method directly.
  def to_assignable_attributes(champ, value)
    screened = screened_value(champ, value)
    return nil if screened.nil?

    { value: screened }
  end

  def acceptable_prefill_value?(value)
    case value
    when Hash  then false
    when Array then value.none? { _1.is_a?(Hash) || _1.is_a?(Array) }
    else true
    end
  end

  def scalar_prefill_value?(value)
    value.is_a?(String) || value.is_a?(Numeric)
  end

  private

  def screened_value(champ, value)
    value if acceptable_prefill_value?(value)
  end

  def link_to_all_possible_values
    return unless prefillable?

    link_to(
      I18n.t("views.prefill_descriptions.edit.possible_values.link.text"),
      Rails.application.routes.url_helpers.prefill_type_de_champ_path(@revision.procedure_path, self),
      title: new_tab_suffix(I18n.t("views.prefill_descriptions.edit.possible_values.link.title")),
      **external_link_attributes
    )
  end

  def too_many_possible_values?
    all_possible_values.count > POSSIBLE_VALUES_THRESHOLD
  end

  def description
    # HtmlSafeTranslation honours the `_html` convention that `I18n.t` ignores.
    @description ||= ActiveSupport::HtmlSafeTranslation.translate("views.prefill_descriptions.edit.possible_values.#{type_champ}_html", default: nil)
  end
end
