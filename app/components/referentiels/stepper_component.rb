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
      "Configuration du champ « #{type_de_champ.libelle} »"
    else
      "Configuration de l’annotation privée « #{type_de_champ.libelle} »"
    end
  end

  def step_title
    if step_component_class == Referentiels::NewFormComponent || (step_component_class == Referentiels::ConfigurationErrorComponent && referentiel.exact_match?)
      "Requête"
    elsif step_component_class == Referentiels::MappingFormComponent
      "Réponse et mapping"
    elsif step_component_class == Referentiels::PrefillAndDisplayComponent
      "Pré remplissage des champs et/ou affichage des données récupérées"
    elsif step_component_class == Referentiels::AutocompleteConfigurationComponent || (step_component == Referentiels::ConfigurationErrorComponent && referentiel.autocomplete?)
      "Configuration de l’autocomplétion"
    end
  end

  def next_step_title
    if step_component_class == Referentiels::NewFormComponent && referentiel.mode == 'autocomplete'
      "Configuration de l’autocomplétion"
    elsif step_component_class == Referentiels::NewFormComponent && referentiel.mode == 'exact_match' || step_component_class == Referentiels::AutocompleteConfigurationComponent
      "Réponse et mapping"
    elsif step_component_class == Referentiels::MappingFormComponent
      "Pré remplissage des champs et/ou affichage des données récupérées"
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
    type_de_champ.public? ? 'Champs du formulaire' : 'Annotations privées'
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
