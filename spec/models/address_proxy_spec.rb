# frozen_string_literal: true

RSpec.describe AddressProxy, type: :model do
  describe '#initialize' do
    subject { AddressProxy.new(champ_or_etablissement) }

    context 'when champ_or_etablissement is an instance of Champ' do
      let(:champ_or_etablissement) { ChampData.new }

      context 'when value_json is nil' do
        before { allow(champ_or_etablissement).to receive(:value_json).and_return(nil) }

        it do
          expect(subject.street_address).to be_nil
          expect(subject.city_name).to be_nil
          expect(subject.postal_code).to be_nil
          expect(subject.city_code).to be_nil
          expect(subject.departement_name).to be_nil
          expect(subject.departement_code).to be_nil
          expect(subject.region_name).to be_nil
          expect(subject.region_code).to be_nil
        end
      end
    end
  end
end
