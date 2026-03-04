# frozen_string_literal: true

describe Champs::COJOChamp, type: :model do
  let(:types_de_champ_public) { [{ type: :cojo }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:external_id) { nil }
  let(:url) { COJOService.new.send(:url) }
  let(:body) { Rails.root.join('spec', 'fixtures', 'files', 'api_cojo', "accreditation_#{response_type}.json").read }
  let(:status) { 200 }
  let(:response_type) { 'yes' }
  let(:accreditation_number) { '123456' }
  let(:accreditation_birthdate) { '21/12/1959' }

  before { stub_request(:post, url).with(body: { accreditationNumber: accreditation_number.to_i, birthdate: accreditation_birthdate }).to_return(body:, status:) }

  describe 'fetch_external_data' do
    before {
      champ.accreditation_number = accreditation_number
      champ.accreditation_birthdate = accreditation_birthdate
    }

    subject { champ.fetch_external_data }

    context 'success (yes)' do
      it { expect(subject.value!).to eq({ accreditation_success: true, accreditation_first_name: 'Florence', accreditation_last_name: 'Griffith-Joyner' }) }
    end

    context 'success (no)' do
      let(:response_type) { 'no' }
      it { expect(subject.value!).to eq({ accreditation_success: false, accreditation_first_name: nil, accreditation_last_name: nil }) }
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
  end

  describe 'fill champ' do
    before do
      champ.update(accreditation_number:, accreditation_birthdate:, data: nil)
      champ.fetch_later!
      champ.fetch!
    end

    subject { champ.reload }

    it 'success (yes)' do
      expect(subject.blank?).to be_falsey
    end

    context 'success (no)' do
      let(:response_type) { 'no' }

      it { expect(subject.blank?).to be_truthy }
    end

    context 'failure (schema)' do
      let(:response_type) { 'invalid' }

      it { expect(subject.blank?).to be_truthy }
    end

    context 'failure (http 401)' do
      let(:status) { 401 }
      let(:response_type) { 'invalid' }

      it { expect(subject.blank?).to be_truthy }
    end
  end
end
