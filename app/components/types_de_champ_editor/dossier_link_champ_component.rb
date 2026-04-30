# frozen_string_literal: true

class TypesDeChampEditor::DossierLinkChampComponent < TypesDeChampEditor::BaseChampComponent
  def initialize(procedures:, type_de_champ:, form:, procedure:)
    super(type_de_champ: type_de_champ, form: form, procedure: procedure)
    @procedures = procedures
  end

  def react_props
    {
      id: dom_id(@type_de_champ, :procedures),
      label: "Sélectionnez la ou les démarches concernées",
      sections:,
      name: @form.field_name(:dossier_link_procedure_ids, multiple: true),
      selected_keys: @type_de_champ.dossier_link_procedure_ids.map(&:to_s),
      'aria-label': "Liste des démarches",
    }
  end

  def sections
    groups = {
      'Démarches publiées' => [],
      'Démarches en test' => [],
      'Démarches closes/dépubliées' => [],
    }

    @procedures.each do |procedure|
      item = { label: "N°#{procedure.id} - #{procedure.libelle}", value: procedure.id.to_s }
      case procedure.aasm_state
      when "publiee" then groups['Démarches publiées'] << item
      when "brouillon" then groups['Démarches en test'] << item
      when "close", "depubliee" then groups['Démarches closes/dépubliées'] << item
      end
    end

    groups.filter_map { |label, items| { label:, items: } if items.present? }
  end
end
