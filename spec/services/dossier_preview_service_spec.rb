# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DossierPreviewService do
  let(:procedure) { create(:procedure) }
  let(:user) { create(:user) }
  let(:service) { described_class.new(procedure:, current_user: user) }
  describe '#dossier' do
    it 'creates a preview dossier tied to the draft revision' do
      expect { service.dossier }.to change { Dossier.where(for_procedure_preview: true).count }.by(1)

      dossier = service.dossier

      expect(dossier).to be_persisted
      expect(dossier).to be_for_procedure_preview
      expect(dossier.state).to eq(Dossier.states.fetch(:brouillon))
      expect(dossier.revision).to eq(procedure.draft_revision)
      expect(dossier.user).to eq(user)
      expect(dossier.champs.loaded?).to be(true)
    end

    it 'reuses an existing preview dossier' do
      service = described_class.new(procedure:, current_user: user)
      first_dossier = service.dossier

      expect { service.dossier }.not_to change { Dossier.where(for_procedure_preview: true).count }
    end
  end

  describe '#edit_path' do
    it 'returns the administrateur preview path' do
      expect(service.edit_path).to eq(Rails.application.routes.url_helpers.apercu_admin_procedure_path(procedure))
    end
  end
end
