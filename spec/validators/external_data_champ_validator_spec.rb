# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataChampValidator do
  let(:champ) { Champs::SiretChamp.new }
  let(:validator) { described_class.new(attributes: {}) }

  before { champ.errors.clear }

  shared_examples 'no error added' do
    it { expect { validator.validate(champ) }.not_to change { champ.errors.size } }
  end

  shared_examples 'adds a permissive error' do
    it { expect { validator.validate(champ) }.to change { champ.errors[:value].size }.by(1) }
  end

  context 'fetched' do
    before { allow(champ).to receive_messages(pending?: false, external_error?: false) }
    include_examples 'no error added'
  end

  context 'pending' do
    before do
      allow(champ).to receive_messages(pending?: true, external_error?: false)
    end
    include_examples 'no error added'
  end

  context 'external_error 404 (not found)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'NF', code: 404)]
      )
    end
    include_examples 'adds a permissive error'
  end

  context 'external_error with a technical code' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503)]
      )
    end
    include_examples 'no error added'
  end

  context 'external_error with a technical retry followed by a 404 (exceptions accumulate)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        fetch_external_data_exceptions: [
          ExternalDataException.new(error: 'boom', code: 503),
          ExternalDataException.new(error: 'NF', code: 404),
        ]
      )
    end
    include_examples 'adds a permissive error'

    it 'uses the error key of the most recent exception' do
      validator.validate(champ)
      expect(champ.errors.map(&:type)).to include(:code_404)
    end
  end

  context 'external_error with a non-404 code and no translation' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'old', code: 500)]
      )
    end
    include_examples 'no error added'
  end
end
