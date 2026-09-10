# frozen_string_literal: true

class Referentiels::StepperComponent < StepperBaseComponent
  delegate :referentiel, :type_de_champ, :procedure, to: :step_component

  def initialize(step_component:)
    super(step_component:)
  end

  def back_link
    helpers.link_to(back_link_label, back_path, class: 'fr-link fr-icon-arrow-left-line fr-link--icon--left fr-icon--sm')
  end

  def title
    if type_de_champ.public?
      t(".configuration_champ", libelle: type_de_champ.libelle)
    else
      t(".configuration_annotation", libelle: type_de_champ.libelle)
    end
  end

  def step_title
    if step_component_class == Referentiels::NewFormComponent || (step_component_class == Referentiels::ConfigurationErrorComponent && referentiel.exact_match?)
      t(".step_title_query")
    elsif step_component_class == Referentiels::MappingFormComponent
      t(".step_title_response_mapping")
    elsif step_component_class == Referentiels::PrefillAndDisplayComponent
      t(".step_title_prefill")
    elsif step_component_class == Referentiels::AutocompleteConfigurationComponent || (step_component == Referentiels::ConfigurationErrorComponent && referentiel.autocomplete?)
      t(".step_title_autocomplete_configuration")
    end
  end

  def next_step_title
    if step_component_class == Referentiels::NewFormComponent && referentiel.mode == 'autocomplete'
      t(".step_title_autocomplete_configuration")
    elsif step_component_class == Referentiels::NewFormComponent && referentiel.mode == 'exact_match' || step_component_class == Referentiels::AutocompleteConfigurationComponent
      t(".step_title_response_mapping")
    elsif step_component_class == Referentiels::MappingFormComponent
      t(".step_title_prefill")
    end
  end

  def current_step
    return 1 if step_component_class.in?([Referentiels::NewFormComponent, Referentiels::ConfigurationErrorComponent])

    case [step_component_class, referentiel.mode]
    when [Referentiels::MappingFormComponent, 'exact_match']
      2
    when [Referentiels::PrefillAndDisplayComponent, 'exact_match']
      3
    when [Referentiels::AutocompleteConfigurationComponent, 'autocomplete']
      2
    when [Referentiels::MappingFormComponent, 'autocomplete']
      3
    when [Referentiels::PrefillAndDisplayComponent, 'autocomplete']
      4
    end
  end

  def step_count
    referentiel.mode == 'exact_match' ? 3 : 4
  end

  private

  def back_link_label
    if type_de_champ.public?
      t("administrateurs.procedures.clone.types_de_champ_public")
    else
      t("administrateurs.procedures.clone.types_de_champ_private")
    end
  end

  def back_path
    if type_de_champ.public?
      helpers.champs_admin_procedure_path(procedure)
    else
      helpers.annotations_admin_procedure_path(procedure)
    end
  end

  def step_component_class = step_component.class
end
