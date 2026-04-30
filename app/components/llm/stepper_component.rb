# frozen_string_literal: true

module LLM
  class StepperComponent < StepperBaseComponent
    delegate :llm_rule_suggestion, to: :step_component
    delegate :procedure_revision, :rule, to: :llm_rule_suggestion
    delegate :procedure, to: :procedure_revision

    def self.step_title(rule_name)
      LLM::Rule.new(rule_name).title
    end

    def initialize(step_component:)
      super(step_component:)
    end

    def back_link
      helpers.link_to(
        "Revenir à l’écran de gestion",
        helpers.admin_procedure_path(procedure),
        class: 'fr-link fr-icon-arrow-left-line fr-link--icon-left'
      )
    end

    def step_title(rule_name = rule)
      self.class.step_title(rule_name)
    end

    def title
      "Amélioration de la qualité du formulaire « #{procedure.libelle} »"
    end

    def next_step_title
      next_rule = LLM::Rule.next_rule(rule)
      step_title(next_rule) rescue ""
    end

    def current_step
      LLM::Rule.new(rule).position
    end

    def step_count
      LLM::Rule::SEQUENCE.count
    end

    def show_stepper?
      !step_component.stepper_finished?
    end
  end
end
