# frozen_string_literal: true

describe Champs::AddressChamp do
  let(:types_de_champ_public) { [{ type: :address }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(value:, value_json:) } }
  let(:value) { nil }
  let(:value_json) { nil }

  context "with value but no data" do
    let(:value) { 'Paris' }

    it do
      expect(champ.address_label).to eq('Paris')
      expect(champ.full_address?).to be_falsey
    end
  end

  context "with value and data" do
    let(:value) { '33 Rue Rébeval 75019 Paris' }
    let(:value_json) do
      {
        "type" => "housenumber",
        "label" => "33 Rue Rébeval 75019 Paris",
        "city_code" => "75119",
        "city_name" => "Paris",
        "postal_code" => "75019",
        "region_code" => "11",
        "region_name" => "Île-de-France",
        "street_name" => "Rue Rébeval",
        "street_number" => "33",
        "street_address" => "33 Rue Rébeval",
        "department_code" => "75",
        "department_name" => "Paris",
      }
    end

    it do
      expect(champ.address_label).to eq('33 Rue Rébeval 75019 Paris')
      expect(champ.full_address?).to be_truthy
      expect(champ.commune).to eq({ name: 'Paris 19e Arrondissement', code: '75119', postal_code: '75019' })
      expect(champ.commune_name).to eq('Paris 19e Arrondissement (75019)')
    end
  end

  context "with wrong code INSEE" do
    let(:value) { 'Rue du Bois Charles 27700 Les Trois Lacs' }
    let(:value_json) do
      {
        "type" => "housenumber",
        "label" => "Rue du Bois Charles 27700 Les Trois Lacs",
        "city_code" => "27058",
        "city_name" => "Les Trois Lacs",
        "postal_code" => "27700",
        "department_code" => "27",
        "department_name" => "Eure",
        "street_address" => "Rue du Bois Charles",
      }
    end

    it do
      expect(champ.address_label).to eq('Rue du Bois Charles 27700 Les Trois Lacs')
      expect(champ.full_address?).to be_truthy
      expect(champ.commune).to eq({ name: 'Les Trois Lacs', code: '27676', postal_code: '27700' })
    end
  end

  context "with empty code postal" do
    let(:value) { '15 rue Baudelaire Nouméa' }
    let(:value_json) do
      {
        "type" => "housenumber",
        "label" => "15 Rue BAUDELAIRE Nouméa",
        "city_code" => "98818",
        "city_name" => "Nouméa",
        "postal_code" => "",
        "department_code" => "988",
        "department_name" => "Nouvelle-Calédonie",
        "street_address" => "15 Rue BAUDELAIRE Nouméa",
      }
    end

    it do
      expect(champ.commune).to eq({ name: 'Nouméa', code: '98818', postal_code: '' })
      expect(champ.commune_name).to eq("Nouméa")
    end
  end

  context 'interaction with new address_component' do
    context 'when the address was filled from the ban' do
      let(:value_json) do
        {
          "type" => "housenumber",
          "label" => "128 Rue Brancion 75015 Paris",
          "geometry" => { "type" => "Point", "coordinates" => [2.301328, 48.828992] },
          "city_code" => "75115",
          "city_name" => "Paris 15e Arrondissement",
          "not_in_ban" => "",
          "postal_code" => "75015",
          "region_code" => "11",
          "region_name" => "Île-de-France",
          "street_name" => "Rue Brancion",
          "country_code" => "FR",
          "country_name" => "France",
          "street_number" => "128",
          "street_address" => "128 Rue Brancion",
          "department_code" => "75",
          "department_name" => "Paris",
        }
      end

      it 'changes to not in ban should reset other filled value' do
        champ.not_in_ban = 'true'
        champ.save!
        expect(champ.value_json).to eq("not_in_ban" => "true", "country_code" => "FR")
      end

      it 'can be printed' do
        expect(champ.to_s).to eq('128 Rue Brancion 75015 Paris')
      end
    end

    context "when the address was filled with an international address" do
      let(:value_json) do
        {
          "label" => "18 rue de la gruyere, Lausanne 1010 Suisse",
          "city_name" => "Lausanne",
          "not_in_ban" => "true",
          "postal_code" => "1010",
          "country_code" => "CH",
          "street_address" => "18 rue de la gruyere",
          "department_code" => "99",
          "department_name" => "Etranger",
        }
      end

      it "changes to in ban should reset other filled value, with FR country_code" do
        champ.not_in_ban = ''
        champ.save!
        expect(champ.value_json).to eq("not_in_ban" => "", "country_code" => "FR")
      end
    end

    context 'legacy addresses' do
      let(:value_json) { nil }

      context 'when address was not refilled' do
        before do
          champ.update(value: '128 Rue Brancion 75015 Paris', value_json: nil)
          Maintenance::T20250513BackfillNoBanAddressTask.new.process(champ)
        end
        it 'to_s successfully' do
          expect(champ.to_s).to eq('128 Rue Brancion 75015 Paris')
        end
      end

      context 'when address was partially filled with an international address' do
        # Champ must first be transformed as international before setting address data
        before { champ.update(country_code: 'CH', not_in_ban: 'true') }

        it 'updates departement_code/name' do
          champ.update(street_address: '18 rue du gruyere')
          expect(champ.value_json).to eq({
            "not_in_ban" => "true",
            "country_code" => "CH",
            "street_address" => '18 rue du gruyere',
            "department_code" => "99",
            "department_name" => "Etranger",
          })
          expect(champ.full_address?).to be_falsey
          expect(champ.to_s).to eq('')
        end
      end

      context 'when address was fully filled with an international address' do
        it 'can be to_s and is considered as full_address' do
          champ.update(not_in_ban: true, country_code: "CH")
          champ.update(street_address: '18 rue de la gruyere', postal_code: '1010', city_name: 'Lausanne')
          expect(champ.full_address?).to be_truthy
          expect(champ.to_s).to eq('18 rue de la gruyere, Lausanne 1010 Suisse')
        end
      end
    end
  end

  describe '#validate_completed' do
    let(:types_de_champ_public) { [{ type: :address, mandatory: }] }
    let(:mandatory) { true }

    context 'when mandatory and ban mode' do
      context 'when address is complete' do
        let(:value) { '33 Rue Rébeval 75019 Paris' }
        let(:value_json) do
          {
            "type" => "housenumber",
            "label" => "33 Rue Rébeval 75019 Paris",
            "city_code" => "75119",
            "city_name" => "Paris",
            "postal_code" => "75019",
            "region_code" => "11",
            "region_name" => "Île-de-France",
            "street_name" => "Rue Rébeval",
            "street_number" => "33",
            "street_address" => "33 Rue Rébeval",
            "department_code" => "75",
            "department_name" => "Paris",
          }
        end

        it 'has no errors' do
          champ.validate_completed
          expect(champ.errors).to be_empty
        end
      end

      context 'when address is empty' do
        let(:value_json) { { "country_code" => "FR" } }

        it 'has errors' do
          champ.validate_completed
          expect(champ.errors).not_to be_empty
          expect(champ.errors.first.type).to eq(:missing)
        end
      end
    end

    context 'when not mandatory and ban mode' do
      let(:mandatory) { false }
      let(:value_json) { { "country_code" => "FR" } }

      it 'has no errors' do
        champ.validate_completed
        expect(champ.errors).to be_empty
      end
    end
  end
end
