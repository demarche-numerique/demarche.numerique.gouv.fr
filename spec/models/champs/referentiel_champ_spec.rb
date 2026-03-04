# frozen_string_literal: true

require 'rails_helper'

describe Champs::ReferentielChamp, type: :model do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:referentiel_champ) { dossier.champs.find(&:referentiel?) }
  let(:champ) { referentiel_champ }

  describe '#valid?' do
    context 'when the champ is pending' do
      before { champ.update_columns(external_state: 'waiting_for_job') }

      it 'adds the correct error message' do
        champ.validate(:champs_public_value)
        expect(champ.errors[:value]).to include(I18n.t('activerecord.errors.messages.api_response_pending'))
      end
    end

    context 'when the champ is fetched' do
      before { champ.update_columns(external_state: 'fetched') }

      it 'is valid' do
        expect(champ.validate(:champs_public_value)).to be_truthy
      end
    end

    context 'when the champ is in error with a non-retryable error' do
      let(:external_data_exceptions) do
        ExternalDataException.new(error: 'Not retryable: 404, 400, 403, 401', code: 404)
      end

      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: [external_data_exceptions]) }

      it 'adds the correct error message' do
        champ.validate(:champs_public_value)

        expect(champ.errors[:value]).to include(I18n.t('activerecord.errors.messages.code_404'))
      end
    end

    context 'when the champ is in error but fetch_external_data_exceptions is empty' do
      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: []) }

      it 'adds the code_unknown error message without raising an error' do
        expect { champ.validate(:champs_public_value) }.not_to raise_error
        expect(champ.errors[:value]).to include(I18n.t('activerecord.errors.messages.code_unknown'))
      end
    end
  end

  describe '#fetch_external_data' do
    subject { referentiel_champ.update_external_data!(data:) }

    context 'when referentiel had not prefill' do
      let(:data) { {} }
      let(:types_de_champ_public) { [type: :referentiel, referentiel: referentiel, referentiel_mapping: nil] }
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
    end

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
    end
  end

  describe 'data=' do
    subject { referentiel_champ.update(data:) }

    context 'when exact_match' do
      let(:referentiel) { create(:api_referentiel, :exact_match) }
      let(:data) { { "ok" => "ko" } }
      it 'supers' do
        expect { subject }.to change { referentiel_champ.reload.data }.to(eq(data))
      end
    end

    context 'when autocomplete' do
      let(:types) { Referentiels::MappingFormComponent::TYPES }
      let(:referentiel) { create(:api_referentiel, :autocomplete, datasource: datasource) }
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            referentiel:,
            referentiel_mapping:,
          },
        ]
      end

      let(:message_encryptor_service) { MessageEncryptorService.new }
      let(:data) { message_encryptor_service.encrypt_and_sign(raw_data, purpose: :storage, expires_in: 1.hour) }

      context 'when data is Hash' do
        let(:datasource) { '$.deep.nested' }
        let(:referentiel_mapping) do
          {
            "$.deep.nested[0].string" => { type: types[:string], display_usager: "1" },
          }
        end
        let(:raw_data) { { "ok" => "ko", 'string' => 'value' } }
        it 'decrypts data and rewrap object in <datasource> as payload' do
          expect { subject }
            .to change { referentiel_champ.reload.data }
            .from(nil)
            .to({ "deep" => { "nested" => [{ "ok" => "ko", 'string' => 'value' }] } })
        end
        it 'saves value json with expected mapping' do
          expect { subject }
            .to change { referentiel_champ.reload.value_json }
            .from(nil)
            .to({ '$.deep.nested[0].string' => 'value' })
        end
      end

      context 'when data is Array' do
        let(:datasource) { '$.' }
        let(:raw_data) { [{ "ok" => "ko", 'string' => 'value' }] }
        let(:referentiel_mapping) do
          {
            "$.[0].string" => { type: types[:string], display_usager: "1" },
          }
        end
        it 'decrypts data and rewrap object in <datasource> as payload' do
          expect { subject }
            .to change { referentiel_champ.reload.data }
            .from(nil)
            .to([[{ "ok" => "ko", 'string' => 'value' }]])
        end
        it 'saves value json with expected mapping' do
          expect { subject }
            .to change { referentiel_champ.reload.value_json }
            .from(nil)
            .to({ "$.[0].string" => 'value' })
        end
      end

      context 'when data is not present' do
        let(:data) { nil }
        let(:datasource) { '$.deep.nested' }
        let(:referentiel_mapping) { {} }
        it 'void data' do
          expect { subject }.not_to change { referentiel_champ.reload.data }
        end
      end
    end
  end
end
