# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserProcedurePresentation, type: :model do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text }]) }

  describe 'associations' do
    it 'belongs to user and procedure' do
      is_expected.to belong_to(:user)
      is_expected.to belong_to(:procedure)
    end
  end

  describe 'validations' do
    it 'délègue la validation aux Column' do
      column = procedure.find_column(label: 'Demandeur')
      allow(column).to receive(:valid?).and_return(false)
      presentation = described_class.new(user:, procedure:, displayed_columns: [column])

      expect(presentation).not_to be_valid
    end
  end

  describe 'displayed_columns' do
    it 'défaut à un tableau vide' do
      presentation = described_class.new(user:, procedure:)
      expect(presentation.displayed_columns).to eq([])
    end

    it 'accepte un tableau de Column' do
      column = procedure.active_revision.types_de_champ.first.columns(procedure:).first
      presentation = described_class.create!(user:, procedure:, displayed_columns: [column])
      expect(presentation.reload.displayed_columns).to all(be_a(Column))
    end
  end

  describe 'unicité user × procedure' do
    it 'empêche deux presentations pour la même paire user/procedure' do
      described_class.create!(user:, procedure:)
      expect {
        described_class.create!(user:, procedure:)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "valide l'unicité au niveau du modèle" do
      described_class.create!(user:, procedure:)

      duplicate = described_class.new(user:, procedure:)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include(I18n.t('errors.messages.taken'))
    end
  end
end
