# frozen_string_literal: true

require 'rails_helper'

describe Champs::ReferentielChamp, type: :model do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:referentiel_champ) { dossier.champs.find(&:referentiel?) }

  describe '#cast_value_for_type_de_champ' do
    subject { referentiel_champ.update_external_data!(data:) }

    context 'when prefill/mapping is configured' do
      let(:prefillable_stable_id) { 2 }
      let(:prefilled_type_de_champ_options) { {} }
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel: referentiel,
            referentiel_mapping: {
              "$.ok" => { prefill: "1", prefill_stable_id: prefillable_stable_id },
            },
          },
          { type: prefilled_type_de_champ_type, stable_id: prefillable_stable_id }.merge(prefilled_type_de_champ_options),
        ]
      end

      describe 'when prefillable_stable_id has been destroyed' do
        let(:prefillable_stable_id) { 9999 }
        let(:prefilled_type_de_champ_type) { :text }

        it 'does not raise an error' do
          expect { subject }.to raise_error(StandardError)
        end
      end

      context 'when data is mapped to text' do
        let(:data) { { ok: 'ok' } }
        let(:prefilled_type_de_champ_type) { :text }

        it 'update the prefiiable stable_id with the jsonpath value of the external data' do
          expect { subject }
            .to change { dossier.reload.project_champs.find(&:text?).value }.from(nil).to("ok")
        end
      end

      context 'when data is mapped to integer_number' do
        let(:prefilled_type_de_champ_type) { :integer_number }

        context 'when data is a string integer' do
          let(:data) { { ok: "42" } }
          it 'casts and updates the integer_number with the jsonpath value as integer' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:integer_number?).value }.from(nil).to("42")
          end
        end

        context 'when data is an integer' do
          let(:data) { { ok: 42 } }
          it 'casts and updates the integer_number with the jsonpath value as integer' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:integer_number?).value }.from(nil).to("42")
          end
        end

        context 'when data is a float' do
          let(:data) { { ok: 42.2 } }
          it 'casts and updates the integer_number with the jsonpath value as integer' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:integer_number?).value }.from(nil).to("42")
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'casts and updates the integer_number with the jsonpath value as integer' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:integer_number?).value }
          end
        end

        context 'when data is blank string' do
          let(:data) { { ok: "" } }
          it 'casts and updates the integer_number with the jsonpath value as integer' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:integer_number?).value }
          end
        end
      end

      context 'when data is mapped to decimal_number' do
        let(:prefilled_type_de_champ_type) { :decimal_number }

        context 'when data is a float' do
          let(:data) { { ok: 3.14 } }
          it 'casts and updates the decimal_number with the jsonpath value as float' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil).to("3.14")
          end
        end

        context 'when data is a string float' do
          let(:data) { { ok: "3.14" } }
          it 'casts and updates the decimal_number with the jsonpath value as float' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil).to("3.14")
          end
        end

        context 'when data is an integer' do
          let(:data) { { ok: 2 } }
          it 'casts and updates the decimal_number with the jsonpath value as float' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil).to("2.0")
          end
        end

        context 'when data is a string integer' do
          let(:data) { { ok: "2" } }
          it 'casts and updates the decimal_number with the jsonpath value as float' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil).to("2.0")
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the decimal_number value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil)
          end
        end

        context 'when data is blank string' do
          let(:data) { { ok: "" } }
          it 'does not update the decimal_number value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:decimal_number?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to checkbox' do
        let(:prefilled_type_de_champ_type) { :checkbox }

        context 'when data is true' do
          let(:data) { { ok: true } }
          it 'casts and updates the checkbox with the jsonpath value as "true"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil).to("true")
          end
        end

        context 'when data is string "true"' do
          let(:data) { { ok: "true" } }
          it 'casts and updates the checkbox with the jsonpath value as "true"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil).to("true")
          end
        end

        context 'when data is 1' do
          let(:data) { { ok: 1 } }
          it 'casts and updates the checkbox with the jsonpath value as "true"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil).to("true")
          end
        end

        context 'when data is string "1"' do
          let(:data) { { ok: "1" } }
          it 'casts and updates the checkbox with the jsonpath value as "true"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil).to("true")
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the checkbox value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil)
          end
        end

        context 'when data is empty string' do
          let(:data) { { ok: "" } }
          it 'does not update the checkbox value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:checkbox?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to yes_no' do
        let(:prefilled_type_de_champ_type) { :yes_no }

        context 'when data is false' do
          let(:data) { { ok: false } }
          it 'casts and updates the yes_no with the jsonpath value as "false"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil).to("false")
          end
        end

        context 'when data is string "false"' do
          let(:data) { { ok: "false" } }
          it 'casts and updates the yes_no with the jsonpath value as "false"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil).to("false")
          end
        end

        context 'when data is 0' do
          let(:data) { { ok: 0 } }
          it 'casts and updates the yes_no with the jsonpath value as "false"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil).to("false")
          end
        end

        context 'when data is string "0"' do
          let(:data) { { ok: "0" } }
          it 'casts and updates the yes_no with the jsonpath value as "false"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil).to("false")
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the yes_no value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil)
          end
        end

        context 'when data is empty string' do
          let(:data) { { ok: "" } }
          it 'does not update the yes_no value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:yes_no?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to date' do
        let(:prefilled_type_de_champ_type) { :date }

        context 'when data is ISO8601 date' do
          let(:data) { { ok: '2024-06-14' } }
          it 'casts and updates the date with the jsonpath value as ISO8601' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:date?).value }.from(nil).to('2024-06-14')
          end
        end

        context 'when data is a unix timestamp' do
          let(:date) { Date.new(2025, 7, 10) }
          let(:data) { { ok: date.to_time.to_i } } # 2025-07-10T00:00:00Z
          it 'convert to ISO8601 date' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:date?).value }.from(nil).to(date.iso8601)
          end
        end

        context 'when data is a unix timestamp as string' do
          let(:date) { Date.new(2025, 7, 10) }
          let(:data) { { ok: date.to_time.to_i.to_s } } # 2025-07-10T00:00:00Z
          it 'convert to ISO8601 date' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:date?).value }.from(nil).to(date.iso8601)
          end
        end

        context 'when data is not a timestamp' do
          let(:data) { { ok: 'not_a_timestamp' } }
          it 'noops' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:date?).value }.from(nil)
          end
        end

        context 'when data is dd/mm/yyyy' do
          let(:data) { { ok: '14/06/2024' } }
          it 'casts and updates the date with the jsonpath value as ISO8601' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:date?).value }.from(nil).to('2024-06-14')
          end
        end

        context 'when data is invalid date' do
          let(:data) { { ok: '2024-13-14' } }
          it 'does not update the date value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:date?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to datetime' do
        let(:prefilled_type_de_champ_type) { :datetime }

        context 'when data is ISO8601 datetime' do
          let(:data) { { ok: '2024-06-14T12:34' } }
          it 'casts and updates the datetime with the jsonpath value as ISO8601' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil).to(Time.zone.parse('2024-06-14T12:34').iso8601)
          end
        end

        context 'when data is dd/mm/yyyy hh:mm' do
          let(:data) { { ok: '14/06/2024 12:34' } }
          it 'casts and updates the datetime with the jsonpath value as ISO8601' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil).to(Time.zone.parse('2024-06-14T12:34').iso8601)
          end
        end

        context 'when data is invalid datetime' do
          let(:data) { { ok: '2024-06-14T25:00' } }
          it 'does not update the datetime value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil)
          end
        end

        context 'when data is a unix timestamp' do
          let(:datetime) { Time.current }
          let(:data) { { ok: datetime.to_f } }
          it 'convert to ISO8601 datetime' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil).to(datetime.iso8601)
          end
        end

        context 'when data is a unix timestamp as string' do
          let(:datetime) { Time.current }
          let(:data) { { ok: datetime.to_f.to_s } }
          it 'convert to ISO8601 datetime' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil).to(datetime.iso8601)
          end
        end

        context 'when data is not a timestamp' do
          let(:data) { { ok: 'not_a_timestamp' } }
          it 'noops' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:datetime?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to drop_down_list' do
        let(:prefilled_type_de_champ_type) { :drop_down_list }

        context 'when data is in options' do
          let(:prefilled_type_de_champ_options) { { options: ['valid'] } }
          let(:data) { { ok: 'valid' } }
          it 'casts and updates the drop_down_list with the jsonpath value as string' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:drop_down_list?).value }.from(nil).to('valid')
          end
        end

        context 'when data is not in options without other' do
          let(:prefilled_type_de_champ_options) { { options: ['valid'] } }
          let(:data) { { ok: 'invalid' } }
          it 'does not cast' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:drop_down_list?).value }
          end
        end

        context 'when data is not in options with other' do
          let(:prefilled_type_de_champ_options) { { options: ['valid'] + [:other] } }
          let(:data) { { ok: 'anything' } }
          it 'allows other' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:drop_down_list?).value }.from(nil).to('anything')
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the drop_down_list value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:drop_down_list?).value }.from(nil)
          end
        end
      end

      context 'when data is mapped to siret' do
        let(:prefilled_type_de_champ_type) { :siret }
        let(:data) { { ok: '13002526500013' } }
        it 'casts and updates the siret champ' do
          expect { subject }
            .to change { dossier.reload.project_champs.find(&:siret?).external_id }.from(nil).to('13002526500013')
        end
        it 'enqueue job' do
          expect { subject }.to have_enqueued_job(ChampFetchExternalDataJob).with(dossier.reload.project_champs.find(&:siret?), '13002526500013')
        end
      end

      context 'when data is mapped to referentiel' do
        let(:prefilled_type_de_champ_type) { :referentiel }
        let(:prefilled_type_de_champ_options) { { referentiel: create(:api_referentiel, :exact_match) } }
        let(:data) { { ok: 'champdapi' } }
        it 'casts and updates the siret champ' do
          expect { subject }
            .to change { dossier.reload.project_champs.reverse.find(&:referentiel?).external_id }.from(nil).to('champdapi')
        end
        it 'enqueue job' do
          expect { subject }.to have_enqueued_job(ChampFetchExternalDataJob).with(dossier.reload.project_champs.reverse.find(&:referentiel?), 'champdapi')
        end
      end

      context 'when data is mapped to multiple_drop_down_list' do
        let(:prefilled_type_de_champ_type) { :multiple_drop_down_list }
        let(:prefilled_type_de_champ_options) { { options: ['valid', 'valid_one', 'valid_two'] } }

        context 'when data is an array of strings' do
          let(:data) { { ok: ['valid', 'valid_one'] } }
          it 'casts and updates the multiple_drop_down_list with the jsonpath value as JSON array' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:multiple_drop_down_list?).value }.from(nil).to(['valid', 'valid_one'].to_json)
          end
        end

        context 'when data is an array of object' do
          let(:data) { { ok: [{ choice: '1' }, { choice: '2' }] } }
          it 'passthru' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:multiple_drop_down_list?).value }
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the multiple_drop_down_list value (remains nil)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:multiple_drop_down_list?).value }.from(nil)
          end
        end

        context 'when data contains invalid options' do
          let(:data) { { ok: ['valid', 'invalid_option'] } }
          it 'allows invalid value due to validation afterward' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:multiple_drop_down_list?).value }.from(nil).to(['valid', 'invalid_option'].to_json)
          end
        end
      end

      context 'when data is mapped to formatted' do
        let(:prefilled_type_de_champ_type) { :formatted }
        let(:data) { { ok: 'texte <b>formaté</b>' } }
        it 'update le champ formatted avec la valeur string' do
          expect { subject }
            .to change { dossier.reload.project_champs.find(&:formatted?).value }.from(nil).to('texte <b>formaté</b>')
        end
      end

      context 'when data is mapped to civilite' do
        let(:prefilled_type_de_champ_type) { :civilite }

        context 'when data is "Monsieur"' do
          let(:data) { { ok: 'Monsieur' } }
          it 'casts to "M."' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("M.")
          end
        end

        context 'when data is "M"' do
          let(:data) { { ok: 'M' } }
          it 'casts to "M."' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("M.")
          end
        end

        context 'when data is "male"' do
          let(:data) { { ok: 'male' } }
          it 'casts to "M."' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("M.")
          end
        end

        context 'when data is "Mme"' do
          let(:data) { { ok: 'Mme' } }
          it 'casts to "Mme"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("Mme")
          end
        end

        context 'when data is "Mademoiselle"' do
          let(:data) { { ok: 'Mademoiselle' } }
          it 'casts to "Mme" (CNIL conformity)' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("Mme")
          end
        end

        context 'when data is "female"' do
          let(:data) { { ok: 'female' } }
          it 'casts to "Mme"' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:civilite?).value }.from(nil).to("Mme")
          end
        end

        context 'when data is unknown value' do
          let(:data) { { ok: 'Dr' } }
          it 'does not update the civilite' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:civilite?).value }
          end
        end

        context 'when data is blank' do
          let(:data) { { ok: '' } }
          it 'does not update the civilite' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:civilite?).value }
          end
        end
      end

      context 'when data is mapped to address' do
        let(:prefilled_type_de_champ_type) { :address }

        context 'when data is a valid string' do
          let(:data) { { ok: '20 avenue de Segur Paris' } }
          it 'sets external_id on the address champ' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:address?).external_id }.from(nil).to("20 avenue de Segur Paris")
          end

          it 'does not set value (stays nil until async BAN resolution)' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:address?).value }
          end
        end

        context 'when data is blank' do
          let(:data) { { ok: '' } }
          it 'does not update the address champ' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:address?).external_id }
          end
        end

        context 'when data is nil' do
          let(:data) { { ok: nil } }
          it 'does not update the address champ' do
            expect { subject }
              .not_to change { dossier.reload.project_champs.find(&:address?).external_id }
          end
        end
      end

      context 'when data is mapped to repetition from root' do
        let(:types_de_champ_public) do
          [
            {
              type: :referentiel,
              referentiel: referentiel,
              referentiel_mapping:,
            },
            {
              type: :repetition,
              children: [
                { type: :text, stable_id: 1 },
              ],
            },
          ]
        end

        context 'when mapping and data are arrays' do
          let(:referentiel_mapping) do
            {
              "$.ok[0].nom" => { prefill: "1", prefill_stable_id: 1 },
            }
          end
          let(:data) { { ok: [{ nom: 'Jeanne', age: 120 }, { nom: "Bob", age: 12 }, {}] } }
          it 'creates a rows' do
            subject
            values = dossier.reload.champs.filter(&:text?).map(&:value)
            expect(values).to include('Jeanne')
            expect(values).to include('Bob')
          end
        end

        context 'when mapping and data are not array' do
          let(:referentiel_mapping) do
            {
              "$.nom" => { prefill: "1", prefill_stable_id: 1 },
            }
          end
          let(:data) { { nom: 'Jeanne', age: 120 } }
          it 'creates a rows' do
            subject
            values = dossier.reload.champs.filter(&:text?).map(&:value)
            expect(values).to include('Jeanne')
          end
        end
      end

      context 'when data is mapped from repetition to other elements' do
        let(:types_de_champ_public) do
          [
            {
              type: :repetition,
              mandatory: true,
              children: [
                {
                  type: :referentiel,
                  referentiel_id: referentiel.id,
                  referentiel_mapping:,
                },
                { type: :text, stable_id: 1 },
              ],
            },
          ]
        end
        let(:repetition_champ) { dossier.champs.find(&:repetition?) }
        let(:referentiel_champ) { repetition_champ.rows.first.find(&:referentiel?) }

        context 'when mapping and data are arrays' do
          let(:referentiel_mapping) do
            {
              "$.ok[0].nom" => { prefill: "1", prefill_stable_id: 1 },
            }
          end
          let(:data) { { ok: [{ nom: 'Jeanne' }, {}] } }

          it 'update current row' do
            expect { subject }.not_to change { repetition_champ.reload.rows.size }
            champs = repetition_champ.rows.first
            expect(champs.find(&:text?).value).to eq('Jeanne')
          end
        end

        context 'when mapping and data are not array' do
          let(:referentiel_mapping) do
            {
              "$.nom" => { prefill: "1", prefill_stable_id: 1 },
            }
          end
          let(:data) { { nom: 'Jeanne' } }
          it 'update existing row' do
            subject
            values = dossier.reload.champs.filter(&:text?).map(&:value)
            expect(values).to include('Jeanne')
          end
        end
      end

      context 'when data is an array of values' do
        let(:types_de_champ_public) do
          [
            {
              type: :referentiel,
              referentiel: referentiel,
              referentiel_mapping: {
                "$.records[0].A" => { prefill: "1", prefill_stable_id: prefillable_stable_id },
              },
            },
            { type: prefilled_type_de_champ_type, stable_id: prefillable_stable_id }.merge(prefilled_type_de_champ_options),
          ]
        end

        context 'when data is mapped to text' do
          let(:data) { { records: [{ A: 'ok' }] } }
          let(:prefilled_type_de_champ_type) { :text }

          it 'update the prefiiable stable_id with the jsonpath value of the external data' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:text?).value }.from(nil).to("ok")
          end
        end
      end

      context 'when data is an array of nested objects (grist like)' do
        let(:types_de_champ_public) do
          [
            {
              type: :referentiel,
              referentiel: referentiel,
              referentiel_mapping: {
                "$.records[0].fields.B" => { prefill: "1", prefill_stable_id: prefillable_stable_id },
              },
            },
            { type: prefilled_type_de_champ_type, stable_id: prefillable_stable_id }.merge(prefilled_type_de_champ_options),
          ]
        end

        context 'when data is mapped to text' do
          let(:data) do
            {
              records: [
                {
                  fields: {
                    B: 'ok',
                  },
                },
              ],
            }
          end
          let(:prefilled_type_de_champ_type) { :text }

          it 'update the prefiiable stable_id with the jsonpath value of the external data' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:text?).value }.from(nil).to("ok")
          end
        end
      end

      context 'when data is an nested array of values' do
        let(:types_de_champ_public) do
          [
            {
              type: :referentiel,
              referentiel: referentiel,
              referentiel_mapping: {
                "$.records[0].A[0].B" => { prefill: "1", prefill_stable_id: prefillable_stable_id },
              },
            },
            { type: prefilled_type_de_champ_type, stable_id: prefillable_stable_id }.merge(prefilled_type_de_champ_options),
          ]
        end

        context 'when data is mapped to text' do
          let(:data) do
            {
              records: [
                {
                  A: [
                    {
                      B: 'ok',
                    },
                  ],
                },
              ],
            }
          end
          let(:prefilled_type_de_champ_type) { :text }

          it 'update the prefiiable stable_id with the jsonpath value of the external data' do
            expect { subject }
              .to change { dossier.reload.project_champs.find(&:text?).value }.from(nil).to("ok")
          end
        end
      end
    end
  end
end
