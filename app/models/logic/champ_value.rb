# frozen_string_literal: true

class Logic::ChampValue < Logic::Term
  CHAMP_VALUE_TYPE = {
    boolean: :boolean, # from yes_no or checkbox champ
    number: :number, # from integer or decimal number champ
    enum: :enum, # a choice from a dropdownlist
    commune_enum: :commune_enum,
    epci_enum: :epci_enum,
    departement_enum: :departement_enum,
    address: :address,
    enums: :enums, # multiple choice from a dropdownlist (multipledropdownlist)
    empty: :empty,
    unmanaged: :unmanaged,
  }

  attr_reader :stable_id

  def initialize(stable_id)
    @stable_id = stable_id
  end

  def sources
    [@stable_id]
  end

  def compute(champs)
    targeted_champ = champ(champs)

    return nil if targeted_champ.nil?
    return nil if !targeted_champ.visible?

    targeted_champ.condition_value
  end

  def to_s(type_de_champs) = type_de_champ(type_de_champs)&.libelle # TODO: gerer le cas ou un tdc est supprimé

  def type(type_de_champs)
    type_de_champ(type_de_champs)&.condition_value_type || CHAMP_VALUE_TYPE.fetch(:unmanaged)
  end

  def errors(type_de_champs)
    if !type_de_champs.map(&:stable_id).include?(stable_id)
      [{ type: :not_available }]
    else
      []
    end
  end

  def to_h
    {
      "term" => self.class.name,
      "stable_id" => @stable_id,
    }
  end

  def self.from_h(h)
    self.new(h['stable_id'])
  end

  def ==(other)
    self.class == other.class && @stable_id == other.stable_id
  end

  def options(type_de_champs, operator_name = nil)
    if operator_name.in?([Logic::InRegionOperator.name, Logic::NotInRegionOperator.name])
      APIGeoService.region_options
    elsif operator_name.in?([Logic::InDepartementOperator.name, Logic::NotInDepartementOperator.name])
      APIGeoService.departement_options
    else
      type_de_champ(type_de_champs).condition_options
    end
  end

  private

  def type_de_champ(type_de_champs)
    type_de_champs.find { |c| c.stable_id == stable_id }
  end

  def champ(champs)
    champs.find { |c| c.stable_id == stable_id }
  end
end
