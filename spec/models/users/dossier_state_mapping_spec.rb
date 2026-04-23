# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::DossierStateMapping do
  describe '.ui_states' do
    it 'exposes the 6 model states in display order' do
      expect(described_class.ui_states).to eq(%w[brouillon en_construction en_instruction accepte refuse sans_suite])
    end
  end
end
