# frozen_string_literal: true

require 'rails_helper'

describe Champs::RNFChamp, type: :model do
  let(:champ) { described_class.new(external_id:) }
  let(:external_id) { '075-FDD-00003-01' }
  let(:body) { Rails.root.join('spec', 'fixtures', 'files', 'api_rnf', "#{response_type}.json").read }
  let(:response_type) { 'valid' }

  describe '#valid?' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.find(&:rnf?) }

    def with_state(external_id:, data:, fetch_external_data_exceptions: [])
      champ.tap do
        _1.external_id = external_id
        _1.data = data
        _1.fetch_external_data_exceptions = fetch_external_data_exceptions
      end
    end

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

    context 'when fetch_external_data_exceptions contains a non-retryable error' do
      let(:error) { ExternalDataException.new(error: 'Not retryable', code: 404) }

      before { champ.update_columns(external_state: 'external_error', fetch_external_data_exceptions: [error]) }

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

  describe 'ready_for_external_call?' do
    subject { champ.ready_for_external_call? }

    context 'when external_id is a partial input' do
      let(:external_id) { '075' }

      it { is_expected.to be false }
    end

    context 'when external_id is a valid RNF format' do
      let(:external_id) { '075-FDD-00003-01' }

      it { is_expected.to be true }
    end

    context 'when external_id is blank' do
      let(:external_id) { nil }

      it { is_expected.to be_falsey }
    end
  end

  describe 'format validation' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.find(&:rnf?) }

    before { champ.update_columns(external_id:) }

    context 'when value is too short' do
      let(:external_id) { 'abc' }

      it 'is invalid' do
        champ.validate(:champs_public_value)
        expect(champ.errors.full_messages.join).to include("pas un numéro RNF valide")
      end
    end

    context 'when value is a valid RNF' do
      let(:external_id) { '075-FDD-00003-01' }

      it 'has no format error' do
        champ.validate(:champs_public_value)
        expect(champ.errors.full_messages.join).not_to include("pas un numéro RNF valide")
      end
    end

    context 'when value is blank' do
      let(:external_id) { nil }

      it 'has no format error' do
        champ.validate(:champs_public_value)
        expect(champ.errors.full_messages.join).not_to include("pas un numéro RNF valide")
      end
    end
  end

  describe 'fetch_external_data' do
    let(:url) { RNFService.new.send(:url) }
    let(:status) { 200 }
    before { stub_request(:get, "#{url}/075-FDD-00003-01").to_return(body:, status:) }

    subject { champ.fetch_external_data }

    context 'success' do
      it do
        expect(subject.value![:data]).to eq({
          id: 3,
          rnfId: '075-FDD-00003-01',
          type: 'FDD',
          department: '75',
          title: 'Fondation SFR',
          dissolvedAt: nil,
          phone: '+33185060000',
          email: 'fondation@sfr.fr',
          addressId: 3,
          createdAt: "2023-09-07T13:26:10.358Z",
          updatedAt: "2023-09-07T13:26:10.358Z",
          address: {
            id: 3,
            createdAt: "2023-09-07T13:26:10.358Z",
            updatedAt: "2023-09-07T13:26:10.358Z",
            label: "16 Rue du Général de Boissieu 75015 Paris",
            type: "housenumber",
            streetAddress: "16 Rue du Général de Boissieu",
            streetNumber: "16",
            streetName: "Rue du Général de Boissieu",
            postalCode: "75015",
            cityName: "Paris",
            cityCode: "75115",
            departmentName: "Paris",
            departmentCode: "75",
            regionName: "Île-de-France",
            regionCode: "11",
          },
          status: nil,
          persons: [],
        })
      end
    end

    context 'success (with space)' do
      let(:external_id) { '075-FDD- 00003-01 ' }
      it {
        expect(subject).to be_success
      }
    end

    context 'success (with tab)' do
      let(:external_id) { '075-FDD-0	0003-01	' }
      it {
        expect(subject).to be_success
      }
    end

    context 'failure (schema)' do
      let(:response_type) { 'invalid' }
      it {
        expect(subject.failure.retryable).to be_falsey
        expect(subject.failure.error).to be_a(API::Client::SchemaError)
      }
    end

    context 'failure (http 500)' do
      let(:status) { 500 }
      let(:response_type) { 'invalid' }
      it {
        expect(subject.failure.retryable).to be_truthy
        expect(subject.failure.error).to be_a(API::Client::HTTPError)
      }
    end

    context 'failure (http 401)' do
      let(:status) { 401 }
      let(:response_type) { 'invalid' }
      it {
        expect(subject.failure.retryable).to be_falsey
        expect(subject.failure.error).to be_a(API::Client::HTTPError)
      }
    end

    context 'failure (http 400)' do
      let(:status) { 400 }
      let(:response_type) { 'invalid' }
      it {
        expect(subject.failure.retryable).to be_falsey
        expect(subject.failure.error).to be_a(API::Client::HTTPError)
      }
    end

    context 'failure (http 404)' do
      let(:status) { 404 }
      let(:response_type) { 'invalid' }
      it {
        expect(subject.failure.retryable).to be_falsey
        expect(subject.failure.error).to be_a(API::Client::HTTPError)
      }
    end

    describe 'update_external_data!' do
      it 'works' do
        value_json = {
          street_number: "16",
          street_name: "Rue du Général de Boissieu",
          street_address: "16 Rue du Général de Boissieu",
          postal_code: "75015",
          city_name: "Paris 15e Arrondissement",
          city_code: "75115",
          departement_code: "75",
          department_code: "75",
          departement_name: "Paris",
          department_name: "Paris",
          region_code: "11",
          region_name: "Île-de-France",
          title: "Fondation SFR",
          country_code: "FR",
          country_name: "France",
        }

        expect(subject.value![:value_json]).to eq(value_json)
      end
    end
  end

  describe 'for_export' do
    let(:champ) { described_class.new(external_id:, data: JSON.parse(body)) }
    before { allow(champ).to receive(:type_de_champ).and_return(build(:type_de_champ_rnf)) }
    it do
      expect(champ.type_de_champ.champ_value_for_export(champ, :value)).to eq '075-FDD-00003-01'
      expect(champ.type_de_champ.champ_value_for_export(champ, :nom)).to eq 'Fondation SFR'
      expect(champ.type_de_champ.champ_value_for_export(champ, :address)).to eq '16 Rue du Général de Boissieu 75015 Paris'
      expect(champ.type_de_champ.champ_value_for_export(champ, :code_insee)).to eq '75115'
      expect(champ.type_de_champ.champ_value_for_export(champ, :departement)).to eq '75 – Paris'
    end
  end
end
