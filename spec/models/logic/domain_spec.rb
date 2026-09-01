# frozen_string_literal: true

describe Logic::Domain do
  describe '.for' do
    it 'builds a domain for every conditionable type' do
      expect(described_class.for(build(:type_de_champ_yes_no))).to be_a(Logic::Domain::Enum)
      expect(described_class.for(build(:type_de_champ_checkbox))).to be_a(Logic::Domain::Enum)
      expect(described_class.for(build(:type_de_champ_integer_number))).to be_a(Logic::Domain::Number)
      expect(described_class.for(build(:type_de_champ_decimal_number))).to be_a(Logic::Domain::Number)
      expect(described_class.for(build(:type_de_champ_drop_down_list))).to be_a(Logic::Domain::Enum)
      expect(described_class.for(build(:type_de_champ_pays))).to be_a(Logic::Domain::Enum)
      expect(described_class.for(build(:type_de_champ_regions))).to be_a(Logic::Domain::Enum)
      expect(described_class.for(build(:type_de_champ_multiple_drop_down_list))).to be_a(Logic::Domain::Enums)
      expect(described_class.for(build(:type_de_champ_departements))).to be_a(Logic::Domain::Geo)
      expect(described_class.for(build(:type_de_champ_communes))).to be_a(Logic::Domain::Geo)
      expect(described_class.for(build(:type_de_champ_epci))).to be_a(Logic::Domain::Geo)
      expect(described_class.for(build(:type_de_champ_address))).to be_a(Logic::Domain::Geo)
    end

    it 'returns nil for unmanaged types' do
      expect(described_class.for(build(:type_de_champ_text))).to be_nil
    end

    it 'distinguishes integers from decimals' do
      expect(described_class.for(build(:type_de_champ_integer_number)).restrict(Logic::GreaterThan, 2).restrict(Logic::LessThan, 3)).to be_empty
      expect(described_class.for(build(:type_de_champ_decimal_number)).restrict(Logic::GreaterThan, 2).restrict(Logic::LessThan, 3)).not_to be_empty
    end

    it 'uses the drop down options' do
      tdc = build(:type_de_champ_drop_down_list, drop_down_options: ['a', 'b'])

      expect(described_class.for(tdc).restrict(Logic::NotEq, 'a').restrict(Logic::NotEq, 'b')).to be_empty
    end

    it 'counts the other option in' do
      tdc = build(:type_de_champ_drop_down_list, drop_down_options: ['a'], drop_down_other: true)

      expect(described_class.for(tdc).restrict(Logic::Eq, Champs::DropDownListChamp::OTHER)).not_to be_empty
    end

    it 'holds the values behind the labels' do
      domain = described_class.for(build(:type_de_champ_regions))

      expect(domain.restrict(Logic::Eq, '84')).not_to be_empty
      expect(domain.restrict(Logic::Eq, 'Auvergne-Rhône-Alpes')).to be_empty
    end
  end

  describe '.for_column' do
    def column(tdc) = tdc.columns(procedure_id: nil).first

    it 'builds a domain for every conditionable column type' do
      expect(described_class.for_column(column(build(:type_de_champ_integer_number))).restrict(Logic::GreaterThan, 2).restrict(Logic::LessThan, 3)).to be_empty
      expect(described_class.for_column(column(build(:type_de_champ_decimal_number))).restrict(Logic::GreaterThan, 2).restrict(Logic::LessThan, 3)).not_to be_empty
      expect(described_class.for_column(column(build(:type_de_champ_yes_no))).restrict(Logic::Eq, true).restrict(Logic::Eq, false)).to be_empty
      expect(described_class.for_column(column(build(:type_de_champ_drop_down_list, drop_down_options: ['a', 'b']))).restrict(Logic::NotEq, 'a').restrict(Logic::NotEq, 'b')).to be_empty
      expect(described_class.for_column(column(build(:type_de_champ_multiple_drop_down_list, drop_down_options: ['a', 'b']))).restrict(Logic::ExcludeOperator, 'a').restrict(Logic::ExcludeOperator, 'b')).to be_empty
    end

    it 'returns nil for other column types' do
      expect(described_class.for_column(column(build(:type_de_champ_text)))).to be_nil
    end
  end
end
