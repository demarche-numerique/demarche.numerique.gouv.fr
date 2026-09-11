# frozen_string_literal: true

require 'rails_helper'

describe Champs::ReferentielChamp, type: :model do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:base_stable_id) { ActiveRecord::Base.connection.select_value("SELECT last_value FROM types_de_champ_id_seq").to_i }
  let(:public_type_de_champs) { [{ type: :referentiel, referentiel: }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:referentiel_champ) { dossier.champ_data.find(&:referentiel?) }
  let(:champ) { dossier.root_champs_public.find(&:referentiel?) }

  describe '#valid?' do
    context 'when the champ is pending' do
      before { champ.update_columns(external_state: 'waiting_for_job') }

      it 'adds the correct error message' do
        champ.validate(:champ_value)
        expect(champ.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.api_response_pending'))
      end
    end

    context 'when the champ is fetched' do
      before { champ.update_columns(external_state: 'fetched') }

      it 'is valid' do
        expect(champ.validate(:champ_value)).to be_truthy
      end
    end

    context 'when the champ is in error with a non-retryable error' do
      let(:external_data_exceptions) do
        ExternalDataException.new(error: 'Not retryable: 404, 400, 403, 401', code: 404)
      end

      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: [external_data_exceptions]) }

      it 'adds the correct error message' do
        champ.validate(:champ_value)

        expect(champ.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.code_404'))
      end
    end

    context 'when the champ is in error but fetch_external_data_exceptions is empty' do
      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: []) }

      it 'adds the code_unknown error message without raising an error' do
        expect { champ.validate(:champ_value) }.not_to raise_error
        expect(champ.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.code_unknown'))
      end
    end
  end

  describe '#fetch! when the API answers 200 with nothing at the result path' do
    let(:public_type_de_champs) { [{ type: :referentiel, referentiel:, referentiel_mapping: }] }
    let(:url) { ReferentielService.new(referentiel:).url("BAD_CODE") }
    let(:collection_mapping) do
      {
        "$.records[0].id" => { type: "integer_number" },
        "$.records[0].fields.Nom" => { type: "string", display_usager: "1" },
      }
    end

    before do
      stub_request(:get, url).to_return(status: 200, body: body.to_json, headers: { 'content-type' => 'application/json' })
      referentiel_champ.update!(external_id: "BAD_CODE")
      referentiel_champ.fetch_later!
      perform_enqueued_jobs
      referentiel_champ.reload
    end

    context 'when the mapping targets the first element of an empty collection' do
      let(:referentiel_mapping) { collection_mapping }
      let(:body) { { records: [] } }

      it 'treats the response as not found' do
        expect(referentiel_champ).to be_external_data_not_found
        expect(referentiel_champ.value).to be_nil
        expect(referentiel_champ.value_json).to be_nil

        referentiel_champ.valid?(:champ_value)
        expect(referentiel_champ.errors).to be_of_kind(:external_id, :code_404)
      end
    end

    context 'when the collection holds a record' do
      let(:referentiel_mapping) { collection_mapping }
      let(:body) { { records: [{ id: 1, fields: { Nom: nil } }] } }

      it 'keeps the response as fetched even when the mapped fields are empty' do
        expect(referentiel_champ).to be_fetched
        expect(referentiel_champ.value).to eq("BAD_CODE")
      end
    end

    context 'when the mapping targets the first element of an empty top-level array' do
      let(:referentiel_mapping) { { "$.[0].nom" => { type: "string", display_usager: "1" } } }
      let(:body) { [] }

      it 'treats the response as not found' do
        expect(referentiel_champ).to be_external_data_not_found
      end
    end

    context 'when the only mapped field is empty' do
      let(:referentiel_mapping) { { "$.records[0].fields.Nom" => { type: "string", display_usager: "1" } } }
      let(:body) { { records: [{ fields: { Nom: nil } }] } }

      it 'treats the response as not found' do
        expect(referentiel_champ).to be_external_data_not_found
      end
    end

    context 'when the only mapped field is false' do
      let(:referentiel_mapping) { { "$.records[0].fields.Actif" => { type: "boolean", display_usager: "1" } } }
      let(:body) { { records: [{ fields: { Actif: false } }] } }

      it 'keeps the response as fetched' do
        expect(referentiel_champ).to be_fetched
      end
    end

    context 'when the referentiel carries its own result path' do
      let(:referentiel) { create(:api_referentiel, :exact_match, result_path: "$.records") }
      let(:referentiel_mapping) { { "$.records[0].fields.Nom" => { type: "string", display_usager: "1" } } }
      let(:body) { { records: [{ fields: { Nom: nil } }] } }

      it 'checks that path rather than the one implied by the mapping' do
        expect(referentiel_champ).to be_fetched
      end
    end
  end

  describe '#fetch_external_data when the champ is inside a repetition' do
    include Dry::Monads[:result]

    let(:public_type_de_champs) do
      [{ type: :repetition, stable_id: 100, children: [{ type: :referentiel, stable_id: 101, referentiel: }] }]
    end
    let(:row_id) { dossier.repetition_add_row(dossier.find_type_de_champ_by_stable_id(100), updated_by: 'test') }
    let(:champ_in_row) { dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(101), row_id:, updated_by: 'test') }

    it 'passes its row_id, so the url tags resolve the champs of this row' do
      champ_in_row.update!(external_id: 'ext-1')

      expect_any_instance_of(ReferentielService).to receive(:call).with('ext-1', dossier:, row_id:).and_return(Success({}))

      champ_in_row.fetch_external_data
    end

    context 'when the champ is on a buffer stream' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }
      let(:champ_on_buffer) do
        dossier.with_update_stream(dossier.user) do
          row_id = dossier.repetition_add_row(dossier.find_type_de_champ_by_stable_id(100), updated_by: 'test')
          dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(101), row_id:, updated_by: 'test')
        end
      end

      it 'resolves the url tags on the stream of the champ, where the row being filled lives' do
        champ_on_buffer.update!(external_id: 'ext-1')

        expect_any_instance_of(ReferentielService).to receive(:call) do |_service, _external_id, dossier:, row_id:|
          expect(dossier.stream).to eq(champ_on_buffer.stream)
          expect(row_id).to eq(champ_on_buffer.row_id)
          Success({})
        end

        champ_on_buffer.fetch_external_data
      end
    end
  end

  describe '#update_external_data! when the referentiel champ is inside a repetition' do
    let(:mapping) { { "$.societes[0].nom" => { prefill: "1", prefill_stable_id: prefilled_stable_id } } }
    let(:own_row_id) { dossier.repetition_add_row(dossier.find_type_de_champ_by_stable_id(100), updated_by: 'test') }
    let(:champ_in_row) { dossier.champ_for_update(dossier.find_type_de_champ_by_stable_id(101), row_id: own_row_id, updated_by: 'test') }

    before { champ_in_row }

    subject(:prefilled) do
      champ_in_row.update_external_data!(data: { societes: [{ nom: 'ACME' }] })
      Dossier.find(dossier.id).champ_data.find { it.stable_id == prefilled_stable_id }
    end

    def row_ids_of(stable_id)
      reloaded = Dossier.find(dossier.id)
      reloaded.repetition_row_ids(reloaded.find_type_de_champ_by_stable_id(stable_id))
    end

    context 'when the prefill targets its own repetition' do
      let(:prefilled_stable_id) { 102 }
      let(:public_type_de_champs) do
        [
          {
            type: :repetition, stable_id: 100, children: [
              { type: :referentiel, stable_id: 101, referentiel:, referentiel_mapping: mapping },
              { type: :text, stable_id: 102 },
            ],
          },
        ]
      end

      it 'keeps the data on its own row, without adding one' do
        rows_before = row_ids_of(100)

        expect(prefilled.value).to eq('ACME')
        expect(prefilled.row_id).to eq(own_row_id)
        expect(row_ids_of(100)).to eq(rows_before)
      end
    end

    # Réutiliser son propre row_id écrirait une ligne de sa répétition dans une autre :
    # aucun marqueur de ligne ne la porterait, la donnée serait persistée mais invisible.
    context 'when a public prefill targets a private repetition' do
      let(:prefilled_stable_id) { 201 }
      let(:public_type_de_champs) do
        [
          {
            type: :repetition, stable_id: 100, children: [
              { type: :referentiel, stable_id: 101, referentiel:, referentiel_mapping: mapping },
            ],
          },
        ]
      end
      let(:private_type_de_champs) do
        [{ type: :repetition, stable_id: 200, children: [{ type: :text, stable_id: 201 }] }]
      end
      let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }

      it 'adds a row to the targeted repetition rather than reusing its own row_id' do
        rows_before = row_ids_of(200)

        expect(prefilled.value).to eq('ACME')
        expect(prefilled.row_id).not_to eq(own_row_id)
        expect(row_ids_of(200) - rows_before).to eq([prefilled.row_id])
      end
    end
  end

  describe '#fetch_external_data' do
    subject { referentiel_champ.update_external_data!(data:) }

    context 'when referentiel had not prefill' do
      let(:data) { {} }
      let(:public_type_de_champs) { [type: :referentiel, referentiel: referentiel, referentiel_mapping: nil] }
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when prefill/mapping is configured' do
      let(:prefillable_stable_id) { base_stable_id + 102 }
      let(:prefilled_type_de_champ_options) { {} }
      let(:public_type_de_champs) do
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

      describe 'prefilled_original_value tracking' do
        let(:data) { { "ok" => "hello" } }
        let(:prefilled_type_de_champ_type) { :text }

        it 'writes prefilled_original_value on the prefilled champ' do
          subject
          prefilled_champ = dossier.champ_data.find { it.stable_id == prefillable_stable_id }
          expect(prefilled_champ.prefilled_original_value).to eq({ "value" => "hello" })
          expect(prefilled_champ.value).to eq("hello")
          expect(prefilled_champ.prefilled?).to be true
        end

        context 'when re-prefilling overwrites the original value' do
          it 'updates prefilled_original_value with new value' do
            subject
            referentiel_champ.reload
            referentiel_champ.update_external_data!(data: { "ok" => "world" })
            prefilled_champ = dossier.reload.champ_data.find { it.stable_id == prefillable_stable_id }
            expect(prefilled_champ.prefilled_original_value).to eq({ "value" => "world" })
          end
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
      let(:public_type_de_champs) do
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
