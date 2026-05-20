# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::DossierStateMapping do
  describe '.ui_states' do
    it 'exposes the 6 model states in display order' do
      expect(described_class.ui_states).to eq(%w[brouillon en_construction en_instruction accepte refuse sans_suite])
    end
  end

  describe '.state_label' do
    it 'maps en_construction to the depose user-facing label' do
      expect(described_class.state_label('en_construction'))
        .to eq(I18n.t('depose', scope: 'activerecord.attributes.dossier/state'))
    end

    it 'reuses the dossier/state translation for other states' do
      %w[brouillon en_instruction accepte refuse sans_suite].each do |state|
        expect(described_class.state_label(state))
          .to eq(I18n.t(state, scope: 'activerecord.attributes.dossier/state'))
      end
    end
  end
end
