# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::AutosaveFooterComponent, type: :component do
  subject(:component) { render_inline(described_class.new(dossier:, annotation:, owner:)) }

  let(:dossier) { create(:dossier) }
  let(:annotation) { false }
  let(:owner) { create(:user) }

  context 'when showing brouillon state (default state)' do
    it 'displays brouillon explanation' do
      expect(component).to have_text("Enregistrement automatique du dossier")
    end
  end

  context 'when editing fork and can pass en construction' do
    let(:dossier) { create(:dossier, :en_construction) }

    it 'displays en construction explanation' do
      expect(component).to have_text("Enregistrement automatique des modifications")
    end
  end

  context 'when showing annotations' do
    let(:annotation) { true }

    it 'displays annotations explanation' do
      expect(component).to have_text("Enregistrement automatique des annotations")
    end
  end
end
