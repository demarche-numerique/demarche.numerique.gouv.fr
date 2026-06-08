# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataChampValidator do
  let(:champ) { Champs::SiretChamp.new }
  let(:validator) { described_class.new(attributes: {}) }

  before { champ.errors.clear }

  shared_examples 'no error added' do
    it { expect { validator.validate(champ) }.not_to change { champ.errors[:value].size } }
  end

  shared_examples 'adds an error' do
    it { expect { validator.validate(champ) }.to change { champ.errors[:value].size }.by(1) }
  end

  context 'fetched' do
    before { allow(champ).to receive_messages(pending?: false, external_error?: false) }
    include_examples 'no error added'
  end

  context 'pending and not required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: true, external_error?: false, external_data_required_for_conditions?: false)
    end
    include_examples 'no error added'
  end

  context 'pending and required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: true, external_error?: false, external_data_required_for_conditions?: true)
    end
    include_examples 'adds an error'
  end

  context 'external_error :not_found and not required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'NF', code: 404, kind: :not_found)]
      )
    end
    include_examples 'adds an error'
  end

  context 'external_error :technical_error and not required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503, kind: :technical_error)]
      )
    end
    include_examples 'no error added'
  end

  context 'external_error :technical_error and required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503, kind: :technical_error)]
      )
    end
    include_examples 'adds an error'
  end

  context 'external_error with legacy nil kind (no condition)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        external_data_required_for_conditions?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'old', code: 500, kind: nil)]
      )
    end
    include_examples 'no error added'
  end
end
