# frozen_string_literal: true

require 'rails_helper'

describe Champs::ReferentielChamp, type: :model do
  include Dry::Monads[:result]

  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:types) { Referentiels::MappingFormComponent::TYPES }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:referentiel_champ) { dossier.project_champs_public.find(&:referentiel?).writable! }

  describe '#cast_displayable_values' do
    before do
      allow_any_instance_of(ReferentielService).to receive(:call).and_return(Success(data))
    end

    subject { referentiel_champ.fetch_external_data.value![:value_json].with_indifferent_access }

    context 'when displayable mapping is configured for string' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.string" => { type: types[:string], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { string: "abc" } }

      it 'casts and stores displayable string value for usager' do
        expect(subject["$.string"]).to eq("abc")
      end
    end

    context 'when displayable mapping is configured for float' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.float" => { type: types[:decimal_number], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { float: 3.14 } }

      it 'casts and stores displayable float value for usager' do
        expect(subject["$.float"]).to eq(3.14)
      end
    end

    context 'when displayable mapping is configured for integer' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.int" => { type: types[:integer_number], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { int: 42 } }

      it 'casts and stores displayable integer value for usager' do
        expect(subject["$.int"]).to eq(42)
      end
    end

    context 'when displayable mapping is configured for boolean' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.bool" => { type: types[:boolean], display_usager: "1" },
            },
          },
        ]
      end

      context 'when true' do
        let(:data) { { bool: true } }

        it 'casts and stores displayable boolean value for usager' do
          expect(subject["$.bool"]).to eq(true)
        end
      end

      context 'when false' do
        let(:data) { { bool: false } }

        it 'casts and stores displayable boolean value for usager' do
          expect(subject["$.bool"]).to eq(false)
        end
      end
    end

    context 'when displayable mapping is configured for date' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.date" => { type: types[:date], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { date: "2024-06-19" } }

      it 'casts and stores displayable date value for usager' do
        expect(subject["$.date"]).to eq("2024-06-19")
      end
    end

    context 'when displayable mapping is configured for datetime' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.datetime" => { type: types[:datetime], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { datetime: "2024-06-19T15:30" } }

      it 'casts and stores displayable datetime value for usager' do
        expect(subject["$.datetime"]).to eq("2024-06-19T15:30:00+02:00")
      end
    end

    context 'when displayable mapping is configured for Liste à choix multiples' do
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.list" => { type: types[:array], display_usager: "1" },
            },
          },
        ]
      end
      let(:data) { { list: ["a", "b", "c"] } }

      it 'casts and stores displayable list value for usager' do
        expect(subject["$.list"]).to eq(["a", "b", "c"])
      end
    end
  end
end
