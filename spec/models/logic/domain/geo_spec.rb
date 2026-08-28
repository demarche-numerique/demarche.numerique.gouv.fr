# frozen_string_literal: true

describe Logic::Domain::Geo do
  let(:domain) { described_class.new }

  it 'is a value: equal domains are one hash key' do
    expect({ domain.restrict(Logic::Eq, '75') => true }).to have_key(described_class.new(['75']))
    expect(domain.restrict(Logic::Eq, '75')).not_to eq(described_class.new(['13']))
  end

  # 01 (Ain) and 69 (Rhône) are in region 84 (Auvergne-Rhône-Alpes), 75 (Paris) in region 11 (Île-de-France)
  it 'narrows with departements' do
    expect(domain).not_to be_empty
    expect(domain.restrict(Logic::InDepartementOperator, '01')).not_to be_empty
    expect(domain.restrict(Logic::InDepartementOperator, '01').restrict(Logic::InDepartementOperator, '69')).to be_empty
    expect(domain.restrict(Logic::InDepartementOperator, '01').restrict(Logic::NotInDepartementOperator, '01')).to be_empty
  end

  it 'narrows with regions' do
    expect(domain.restrict(Logic::InRegionOperator, '84').restrict(Logic::InRegionOperator, '11')).to be_empty
    expect(domain.restrict(Logic::InRegionOperator, '84').restrict(Logic::NotInRegionOperator, '84')).to be_empty
    expect(domain.restrict(Logic::InRegionOperator, '84').restrict(Logic::NotInDepartementOperator, '01')).not_to be_empty
  end

  it 'relates departements to their region' do
    expect(domain.restrict(Logic::InDepartementOperator, '01').restrict(Logic::InRegionOperator, '84')).not_to be_empty
    expect(domain.restrict(Logic::InDepartementOperator, '01').restrict(Logic::InRegionOperator, '11')).to be_empty
    expect(domain.restrict(Logic::InDepartementOperator, '01').restrict(Logic::NotInRegionOperator, '84')).to be_empty
  end

  it 'treats Etranger as its own region' do
    expect(domain.restrict(Logic::InRegionOperator, '99').restrict(Logic::InDepartementOperator, '99')).not_to be_empty
    expect(domain.restrict(Logic::InRegionOperator, '11').restrict(Logic::InDepartementOperator, '99')).to be_empty
  end

  it 'accepts departement equality (departement champ)' do
    expect(domain.restrict(Logic::Eq, '75').restrict(Logic::InRegionOperator, '11')).not_to be_empty
    expect(domain.restrict(Logic::Eq, '75').restrict(Logic::NotEq, '75')).to be_empty
    expect(domain.restrict(Logic::Eq, '75').restrict(Logic::InRegionOperator, '84')).to be_empty
  end

  describe '#regions' do
    include_examples 'domain regions', [[Logic::InDepartementOperator, '01'], [Logic::NotInDepartementOperator, '75'], [Logic::InRegionOperator, '84'], [Logic::NotInRegionOperator, '11'], [Logic::Eq, '69']]

    it 'isolates departements, then the rest of the regions, then the rest' do
      regions = domain.regions([[Logic::InDepartementOperator, '01'], [Logic::InRegionOperator, '84']])

      expect(regions.size).to eq(3)
      expect(regions.first.codes).to eq(Set['01'])
      expect(regions.second.codes).to include('69')
      expect(regions.second.codes).not_to include('01')
      expect(regions.third.codes).to include('75')
      expect(regions.third.codes).not_to include('01', '69')
    end

    it 'isolates Etranger as a region' do
      regions = domain.regions([[Logic::InRegionOperator, '99']])

      expect(regions.map(&:codes)).to eq([Set['99'], domain.codes - ['99']])
    end

    it 'is the whole domain without atoms' do
      expect(domain.regions([])).to eq([domain])
    end
  end

  describe '#union' do
    it 'joins the departements and refuses other kinds' do
      expect(domain.restrict(Logic::Eq, '01').union(domain.restrict(Logic::Eq, '75')).codes).to eq(Set['01', '75'])
      expect(domain.union(Logic::Domain::Blank)).to be_nil
    end
  end

  describe '#to_s' do
    it 'names whole regions and lists the other departements' do
      expect(domain.to_s).to eq('tous les départements')
      expect(domain.restrict(Logic::InDepartementOperator, '01').to_s).to eq('01 – Ain')
      expect(domain.restrict(Logic::InRegionOperator, '84').to_s).to eq('Auvergne-Rhône-Alpes')
      expect(domain.restrict(Logic::InRegionOperator, '84').union(domain.restrict(Logic::Eq, '75')).to_s).to eq('Auvergne-Rhône-Alpes, 75 – Paris')
    end

    it 'counts when the list is too long' do
      expect(domain.restrict(Logic::NotInDepartementOperator, '01').to_s).to eq("#{domain.codes.size - 1} départements")
      expect(described_class.new(%w[01 02 03 04 05 06]).to_s).to eq('01 – Ain, 02 – Aisne, 03 – Allier, 04 – Alpes-de-Haute-Provence, 05 – Hautes-Alpes, 06 – Alpes-Maritimes')
      expect(described_class.new(%w[01 02 03 04 05 06 07]).to_s).to eq('7 départements')
    end
  end
end
