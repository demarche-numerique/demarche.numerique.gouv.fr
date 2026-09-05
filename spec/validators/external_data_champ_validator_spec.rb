# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalDataChampValidator do
  let(:champ) { Champs::SiretChamp.new }
  let(:validator) { described_class.new(attributes: {}) }

  # Every context below is about a champ whose fetch has been attempted;
  # the early return in #validate only skips idle and fetched champs.
  before { allow(champ).to receive_messages(idle?: false, fetched?: false) }

  shared_examples 'no error added' do
    it { expect { validator.validate(champ) }.not_to change { champ.errors.size } }
  end

  shared_examples 'adds a permissive error' do
    it { expect { validator.validate(champ) }.to change { champ.errors[:value].size }.by(1) }
  end

  shared_examples 'adds a strict error' do
    it { expect { validator.validate(champ) }.to change { champ.errors[:external_id].size }.by(1) }
  end

  context 'fetched' do
    before { allow(champ).to receive_messages(fetched?: true) }
    include_examples 'no error added'
  end

  context 'pending and not required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: true, external_error?: false, permissive_external_data_validation?: true)
    end
    include_examples 'no error added'
  end

  context 'pending and required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: true, external_error?: false, permissive_external_data_validation?: false)
    end
    include_examples 'adds a strict error'
  end

  context 'degraded and not required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: false, degraded?: true, external_error?: false, permissive_external_data_validation?: true)
    end
    include_examples 'no error added'
  end

  context 'degraded and required for conditions' do
    before do
      allow(champ).to receive_messages(pending?: false, degraded?: true, external_error?: false, permissive_external_data_validation?: false)
    end
    include_examples 'adds a strict error'
  end

  context 'external_error 404 (not found) and not required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'NF', code: 404)]
      )
    end
    include_examples 'adds a permissive error'
  end

  [422, 451].each do |code|
    context "external_error #{code} (definitive answer) and not required for conditions" do
      before do
        allow(champ).to receive_messages(
          pending?: false, external_error?: true,
          permissive_external_data_validation?: true,
          fetch_external_data_exceptions: [ExternalDataException.new(error: 'definitive', code:)]
        )
      end
      include_examples 'adds a permissive error'

      it 'uses the code-specific message' do
        validator.validate(champ)
        expect(champ.errors.map(&:type)).to include(:"code_#{code}")
      end
    end
  end

  context 'external_error with a technical code and not required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503)]
      )
    end
    include_examples 'no error added'
  end

  context 'external_error with a technical code and required for conditions' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: false,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503)]
      )
    end
    include_examples 'adds a strict error'
  end

  context 'external_error with a technical retry followed by a 404 (exceptions accumulate)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: true,
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

  context 'external_error with accumulated exceptions and required for conditions (strict path)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: false,
        fetch_external_data_exceptions: [
          ExternalDataException.new(error: 'boom', code: 503),
          ExternalDataException.new(error: 'NF', code: 404),
        ]
      )
    end
    include_examples 'adds a strict error'

    it 'uses the error key of the most recent exception' do
      validator.validate(champ)
      expect(champ.errors.map(&:type)).to include(:code_404)
    end
  end

  context 'external_error with a non-404 code and no translation (no condition)' do
    before do
      allow(champ).to receive_messages(
        pending?: false, external_error?: true,
        permissive_external_data_validation?: true,
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'old', code: 500)]
      )
    end
    include_examples 'no error added'
  end
end
