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

      it 'does not block submission (pending is non-blocking)' do
        expect(champ.validate(:champs_public_value)).to be_truthy
        expect(champ.errors[:value]).to be_empty
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
        ExternalDataException.new(error: 'Not retryable: 404, 400, 403, 401', code: 404, kind: :not_found)
      end

      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: [external_data_exceptions]) }

      it 'adds the correct error message' do
        champ.validate(:champs_public_value)

        expect(champ.errors[:value]).to include(I18n.t('activerecord.errors.messages.code_404'))
      end
    end

    context 'when the champ is in error but fetch_external_data_exceptions is empty' do
      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: []) }

      it 'does not block submission and does not raise on empty exceptions' do
        expect { champ.validate(:champs_public_value) }.not_to raise_error
        expect(champ.errors[:value]).to be_empty
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

  describe '#fetch_external_data (kind classification)' do
    include Dry::Monads[:result]

    let(:service) { instance_double(ReferentielService) }

    before { allow(ReferentielService).to receive(:new).and_return(service) }

    context 'when the service returns a non-retryable 404 (search not found)' do
      before do
        allow(service).to receive(:call)
          .and_return(Failure(retryable: false, error: StandardError.new('Not retryable: 404'), code: 404))
      end

      it 'wraps as kind: :not_found' do
        expect(champ.fetch_external_data.failure[:kind]).to eq(:not_found)
        expect(champ.fetch_external_data.failure[:code]).to eq(404)
      end
    end

    context 'when the service returns a retryable failure (5xx)' do
      before do
        allow(service).to receive(:call)
          .and_return(Failure(retryable: true, error: StandardError.new('Retryable: 503'), code: 503))
      end

      it 'wraps as kind: :technical_error' do
        expect(champ.fetch_external_data.failure[:kind]).to eq(:technical_error)
      end
    end

    context 'when the service returns a non-retryable auth error (401)' do
      before do
        allow(service).to receive(:call)
          .and_return(Failure(retryable: false, error: StandardError.new('Not retryable: 401'), code: 401))
      end

      it 'wraps as kind: :technical_error (admin config/auth issue must not block the user)' do
        expect(champ.fetch_external_data.failure[:kind]).to eq(:technical_error)
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
