# frozen_string_literal: true

class Logic::ChampValue < Logic::Term
  MANAGED_TYPE_DE_CHAMP = TypeDeChamp.type_champs.slice(
    :yes_no,
    :checkbox,
    :integer_number,
    :decimal_number,
    :drop_down_list,
    :multiple_drop_down_list,
    :address,
    :communes,
    :epci,
    :departements,
    :regions,
    :pays,
    :pre_rempli
  )

  MANAGED_TYPE_DE_CHAMP_BY_CATEGORY = MANAGED_TYPE_DE_CHAMP.keys.map(&:to_sym)
    .each_with_object(Hash.new { |h, k| h[k] = [] }) do |type, h|
    h[TypeDeChamp::TYPE_DE_CHAMP_TO_CATEGORIE[type]] << type
  end

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
    return nil if targeted_champ.blank? && !targeted_champ.drop_down_other?

    case targeted_champ.class.name
    when "Champs::YesNoChamp",
      "Champs::CheckboxChamp"
      targeted_champ.true?
    when "Champs::IntegerNumberChamp", "Champs::DecimalNumberChamp"
      # TODO expose raw typed value of champs
      targeted_champ.type_de_champ.champ_value_for_api(targeted_champ, version: 1)
    when "Champs::DropDownListChamp"
      targeted_champ.selected
    when "Champs::PreRempliChamp"
      targeted_champ.selected
    when "Champs::MultipleDropDownListChamp"
      targeted_champ.selected_options
    when "Champs::RegionChamp", "Champs::PaysChamp"
      targeted_champ.code
    when "Champs::DepartementChamp"
      {
        value: targeted_champ.code,
        region_code: targeted_champ.code_region,
      }
    when "Champs::CommuneChamp", "Champs::EpciChamp", "Champs::AddressChamp"
      {
        department_code: targeted_champ.code_departement,
        region_code: targeted_champ.code_region,
      }
    end
  end

  def to_s(type_de_champs) = type_de_champ(type_de_champs)&.libelle # TODO: gerer le cas ou un tdc est supprimé

  def type(type_de_champs)
    case type_de_champ(type_de_champs)&.type_champ # TODO: gerer le cas ou un tdc est supprimé
    when MANAGED_TYPE_DE_CHAMP.fetch(:yes_no),
      MANAGED_TYPE_DE_CHAMP.fetch(:checkbox)
      CHAMP_VALUE_TYPE.fetch(:boolean)
    when MANAGED_TYPE_DE_CHAMP.fetch(:integer_number), MANAGED_TYPE_DE_CHAMP.fetch(:decimal_number)
      CHAMP_VALUE_TYPE.fetch(:number)
    when MANAGED_TYPE_DE_CHAMP.fetch(:drop_down_list),
      MANAGED_TYPE_DE_CHAMP.fetch(:regions), MANAGED_TYPE_DE_CHAMP.fetch(:pays),
      MANAGED_TYPE_DE_CHAMP.fetch(:pre_rempli)
      CHAMP_VALUE_TYPE.fetch(:enum)
    when MANAGED_TYPE_DE_CHAMP.fetch(:communes)
      CHAMP_VALUE_TYPE.fetch(:commune_enum)
    when MANAGED_TYPE_DE_CHAMP.fetch(:epci)
      CHAMP_VALUE_TYPE.fetch(:epci_enum)
    when MANAGED_TYPE_DE_CHAMP.fetch(:departements)
      CHAMP_VALUE_TYPE.fetch(:departement_enum)
    when MANAGED_TYPE_DE_CHAMP.fetch(:address)
      CHAMP_VALUE_TYPE.fetch(:address)
    when MANAGED_TYPE_DE_CHAMP.fetch(:multiple_drop_down_list)
      CHAMP_VALUE_TYPE.fetch(:enums)
    else
      CHAMP_VALUE_TYPE.fetch(:unmanaged)
    end
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
    tdc = type_de_champ(type_de_champs)

    if operator_name.in?([Logic::InRegionOperator.name, Logic::NotInRegionOperator.name]) || tdc.type_champ == MANAGED_TYPE_DE_CHAMP.fetch(:regions)
      APIGeoService.region_options
    elsif operator_name.in?([Logic::InDepartementOperator.name, Logic::NotInDepartementOperator.name]) || tdc.type_champ.in?([MANAGED_TYPE_DE_CHAMP.fetch(:communes), MANAGED_TYPE_DE_CHAMP.fetch(:epci), MANAGED_TYPE_DE_CHAMP.fetch(:departements), MANAGED_TYPE_DE_CHAMP.fetch(:address)])
      APIGeoService.departement_options
    elsif tdc.type_champ == MANAGED_TYPE_DE_CHAMP.fetch(:pays)
      APIGeoService.countries.map { ["#{_1[:name]} – #{_1[:code]}", _1[:code]] }
    else
      tdc.options_for_select_with_other
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
