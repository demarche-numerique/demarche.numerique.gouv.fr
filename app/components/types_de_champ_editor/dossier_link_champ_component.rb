# frozen_string_literal: true

class TypesDeChampEditor::DossierLinkChampComponent < TypesDeChampEditor::BaseChampComponent
  def initialize(procedures:, type_de_champ:, form:, procedure:)
    super(type_de_champ: type_de_champ, form: form, procedure: procedure)
    @procedures = procedures
  end

  def react_props
    {
      trigger_id: dom_id(@type_de_champ, :procedures),
      label: t(".label"),
      sections:,
      name: @form.field_name(:dossier_link_procedure_ids, multiple: true),
      value: @type_de_champ.dossier_link_procedure_ids.map(&:to_s),
      placeholder: t('views.components.multiple_combobox'),
    }
  end

  def sections
    groups = {
      published: [],
      test: [],
      closed: [],
    }

    @procedures.each do |procedure|
      item = { label: t(".item_label", id: procedure.id, libelle: procedure.libelle), value: procedure.id.to_s }
      case procedure.aasm_state
      when "publiee" then groups[:published] << item
      when "brouillon" then groups[:test] << item
      when "close", "depubliee" then groups[:closed] << item
      end
    end

    labels = {
      published: t(".published_procedures"),
      test: t(".test_procedures"),
      closed: t(".closed_procedures"),
    }
    groups.filter_map { |key, items| { label: labels[key], items: } if items.present? }
  end
end
