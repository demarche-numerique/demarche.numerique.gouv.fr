# frozen_string_literal: true

class ProcedureRevisionChange
  class TypeDeChange
    attr_reader :type_de_champ
    def initialize(type_de_champ)
      @type_de_champ = type_de_champ
    end

    def label = @type_de_champ.libelle
    def stable_id = @type_de_champ.stable_id
    def private? = @type_de_champ.private?

    def to_h = { op:, stable_id:, label:, private: private? }
  end

  class AddChamp < TypeDeChange
    def initialize(type_de_champ)
      super(type_de_champ)
    end

    def op = :add
    def mandatory? = @type_de_champ.mandatory?

    def to_h = super.merge(mandatory: mandatory?)
  end

  class RemoveChamp < TypeDeChange
    def initialize(type_de_champ)
      super(type_de_champ)
    end

    def op = :remove
  end

  class MoveChamp < TypeDeChange
    attr_reader :from, :to

    def initialize(type_de_champ, from, to)
      super(type_de_champ)
      @from = from
      @to = to
    end

    def op = :move
    def to_h = super.merge(from:, to:)
  end

  class UpdateChamp < TypeDeChange
    attr_reader :attribute, :from, :to

    def initialize(type_de_champ, attribute, from, to)
      super(type_de_champ)
      @attribute = attribute
      @from = from
      @to = to
    end

    def op = :update
    def to_h = super.merge(attribute:, from:, to:)
  end

  class EligibiliteRulesChange
    attr_reader :previous_revision, :new_revision
    def initialize(previous_revision, new_revision)
      @previous_revision = previous_revision
      @new_revision = new_revision
      @previous_ineligibilite_rules = @previous_revision.ineligibilite_rules
      @new_ineligibilite_rules = @new_revision.ineligibilite_rules
    end

    def i18n_params
      {
        previous_condition: @previous_ineligibilite_rules&.to_s(previous_revision.types_de_champ.filter { @previous_ineligibilite_rules.sources.include? _1.stable_id }),
        new_condition: @new_ineligibilite_rules&.to_s(new_revision.types_de_champ.filter { @new_ineligibilite_rules.sources.include? _1.stable_id }),
      }
    end
  end

  class AddEligibiliteRuleChange < EligibiliteRulesChange
    def op = :add
  end

  class RemoveEligibiliteRuleChange < EligibiliteRulesChange
    def op = :remove
  end

  class UpdateEligibiliteRuleChange < EligibiliteRulesChange
    def op = :update
  end

  class EligibiliteEnabledChange < EligibiliteRulesChange
    def op = :enabled
    def i18n_params = {}
  end

  class EligibiliteDisabledChange < EligibiliteRulesChange
    def op = :disabled
    def i18n_params = {}
  end

  class UpdateEligibiliteMessageChange < EligibiliteRulesChange
    def op = :message_updated
    def i18n_params = { ineligibilite_message: @new_revision.ineligibilite_message }
  end
end
