# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::DossierStateMapping do
  describe '.model_state_for' do
    it 'maps :depose to en_construction' do
      expect(described_class.model_state_for('depose')).to eq('en_construction')
    end

    it 'returns the input for other known states' do
      %w[brouillon en_instruction accepte refuse sans_suite].each do |state|
        expect(described_class.model_state_for(state)).to eq(state)
      end
    end

    it 'returns nil for unknown states' do
      expect(described_class.model_state_for('unknown')).to be_nil
    end
  end

  describe '.ui_states' do
    it 'exposes the 6 UI states in display order' do
      expect(described_class.ui_states).to eq(%w[brouillon depose en_instruction accepte refuse sans_suite])
    end
  end
end
