# frozen_string_literal: true

module LLM
  class Rule
    SEQUENCE = %w[improve_label improve_structure improve_types cleaner].freeze

    CONFIG = {
      'improve_label' => {
        title: "Libellés et descriptions des champs",
        component_class: 'LLM::ImproveLabelItemComponent',
        service_class: 'LLM::LabelImprover',
        ordering: -> (suggestion) { LLM::SuggestionOrderingService.ordered_label_suggestions(suggestion) },
        summary: "Cette étape propose une mise à jour des libellés pour les rendre plus clairs et compréhensibles pour l'usager.",
      },
      'improve_structure' => {
        title: "Structure du formulaire",
        component_class: 'LLM::ImproveStructureItemComponent',
        service_class: 'LLM::StructureImprover',
        ordering: -> (suggestion) { LLM::SuggestionOrderingService.ordered_structure_suggestions(suggestion) },
        summary: "Cette étape propose des suggestions d'amélioration de la structure du formulaire (réorganisation des champs, ajout de sections) pour le rendre plus clair et lisible pour l'usager.",
      },
      'improve_types' => {
        title: "Bonne utilisation des types de champs",
        component_class: 'LLM::ImproveTypesItemComponent',
        service_class: 'LLM::TypesImprover',
        ordering: -> (suggestion) { LLM::SuggestionOrderingService.ordered_label_suggestions(suggestion) },
        summary: "Cette étape permet d'utiliser les types de champs appropriés (email, adresse, etc.) pour un affichage optimisé et une validation automatique.",
      },
      'cleaner' => {
        title: "Demande unique d’information",
        component_class: 'LLM::CleanerItemComponent',
        service_class: 'LLM::CleanerImprover',
        ordering: -> (suggestion) { LLM::SuggestionOrderingService.ordered_label_suggestions(suggestion) },
        summary: "Cette étape applique le principe « Dites-le nous une fois » : l'administration ne doit pas redemander des informations déjà collectées ou connues par ailleurs.",
      },
    }.freeze

    attr_reader :name

    def initialize(rule_name)
      @name = rule_name
      @config = self.class.config_for(rule_name)
    end

    def self.config_for(rule_name)
      CONFIG.fetch(rule_name) { raise ArgumentError, "Unknown rule: #{rule_name}" }
    end

    def title
      @config[:title]
    end

    def summary
      @config[:summary]
    end

    def component_class
      @config[:component_class].constantize
    end

    def service_class
      @config[:service_class].constantize
    end

    def ordered_items(suggestion)
      @config[:ordering].call(suggestion)
    end

    def next_rule
      index = SEQUENCE.index(name)
      return nil if index.nil? || index >= SEQUENCE.length - 1
      SEQUENCE[index + 1]
    end

    def last?
      name == SEQUENCE.last
    end

    def position
      SEQUENCE.index(name)&.next
    end

    def self.next_rule(current_rule)
      return SEQUENCE.first if current_rule.nil?
      new(current_rule).next_rule
    end

    def self.last?(rule_name)
      new(rule_name).last?
    end
  end
end
