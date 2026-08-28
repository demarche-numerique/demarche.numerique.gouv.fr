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
end
