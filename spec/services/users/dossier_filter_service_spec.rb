# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::DossierFilterService do
  let(:user) { create(:user) }
  let!(:own_dossier) { create(:dossier, :en_construction, user: user) }
  let!(:invited_dossier) do
    d = create(:dossier, :en_construction)
    create(:invite, dossier: d, user: user)
    d
  end
  let!(:other_dossier) { create(:dossier, :en_construction) }
  let!(:hidden_dossier) { create(:dossier, :en_construction, user: user, hidden_by_user_at: Time.current) }

  subject(:service) { described_class.new(user: user, params: ActionController::Parameters.new) }

  describe '#base_scope' do
    it 'includes own visible dossiers' do
      expect(service.base_scope).to include(own_dossier)
    end

    it 'includes invited dossiers' do
      expect(service.base_scope).to include(invited_dossier)
    end

    it 'excludes other users dossiers' do
      expect(service.base_scope).not_to include(other_dossier)
    end

    it 'excludes dossiers hidden by user' do
      expect(service.base_scope).not_to include(hidden_dossier)
    end
  end

  describe '#base_scope with search' do
    let(:params) { ActionController::Parameters.new(search: own_dossier.id.to_s) }
    subject(:service) { described_class.new(user: user, params: params) }

    it 'restricts base_scope to search results' do
      expect(service.base_scope).to include(own_dossier)
      expect(service.base_scope).not_to include(invited_dossier)
    end
  end

  describe '#dossiers with procedure_id filter' do
    let(:procedure_a) { create(:procedure) }
    let(:procedure_b) { create(:procedure) }
    let!(:dossier_a) { create(:dossier, :en_construction, user: user, procedure: procedure_a) }
    let!(:dossier_b) { create(:dossier, :en_construction, user: user, procedure: procedure_b) }

    subject(:service) { described_class.new(user: user, params: ActionController::Parameters.new(procedure_id: procedure_a.id.to_s)) }

    it 'keeps only dossiers of the given procedure' do
      expect(service.dossiers).to include(dossier_a)
      expect(service.dossiers).not_to include(dossier_b)
    end
  end

  describe '#dossiers with shared_with_me filter' do
    subject(:service) { described_class.new(user: user, params: ActionController::Parameters.new(shared_with_me: '1')) }

    it 'keeps only invited dossiers' do
      expect(service.dossiers).to include(invited_dossier)
      expect(service.dossiers).not_to include(own_dossier)
    end
  end

  describe '#dossiers with state filter' do
    let!(:brouillon) { create(:dossier, user: user) }
    let!(:en_construction) { create(:dossier, :en_construction, user: user) }
    let!(:en_instruction) { create(:dossier, :en_instruction, user: user) }
    let!(:accepte) { create(:dossier, :accepte, user: user) }

    it 'filters by a single UI state' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['depose']))
      expect(service.dossiers).to include(en_construction)
      expect(service.dossiers).not_to include(brouillon, en_instruction, accepte)
    end

    it 'filters by multiple states (OR)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['brouillon', 'depose']))
      expect(service.dossiers).to include(brouillon, en_construction)
      expect(service.dossiers).not_to include(en_instruction, accepte)
    end

    it 'ignores unknown state values' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['unknown']))
      expect(service.dossiers).to include(own_dossier, invited_dossier, brouillon, en_construction, en_instruction, accepte)
    end
  end

  describe '#dossiers with date filters' do
    let!(:old_dossier) { create(:dossier, :en_construction, user: user, created_at: 30.days.ago, depose_at: 25.days.ago) }
    let!(:recent_dossier) { create(:dossier, :en_construction, user: user, created_at: 1.day.ago, depose_at: 1.hour.ago) }

    it 'filters by from_created_at_date' do
      date = 7.days.ago.to_date.iso8601
      service = described_class.new(user: user, params: ActionController::Parameters.new(from_created_at_date: date))
      expect(service.dossiers).to include(recent_dossier)
      expect(service.dossiers).not_to include(old_dossier)
    end

    it 'filters by from_depose_at_date' do
      date = 7.days.ago.to_date.iso8601
      service = described_class.new(user: user, params: ActionController::Parameters.new(from_depose_at_date: date))
      expect(service.dossiers).to include(recent_dossier)
      expect(service.dossiers).not_to include(old_dossier)
    end

    it 'ignores invalid date format' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(from_created_at_date: 'not-a-date'))
      expect { service.dossiers.to_a }.not_to raise_error
      expect(service.dossiers).to include(old_dossier, recent_dossier)
    end
  end

  describe '#dossiers with alert filter' do
    let!(:dossier_pending_correction) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_pending_response) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_unread_message) { create(:dossier, :en_construction, user: user) }

    before do
      create(:dossier_correction, dossier: dossier_pending_correction)
      create(:dossier_pending_response, dossier: dossier_pending_response)
      create(:commentaire, dossier: dossier_unread_message, instructeur: create(:instructeur), seen_by_recipient_at: nil)
    end

    it 'filters by a_corriger' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['a_corriger']))
      expect(service.dossiers).to include(dossier_pending_correction)
      expect(service.dossiers).not_to include(dossier_pending_response, dossier_unread_message)
    end

    it 'filters by message_avec_attente_de_reponse' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['message_avec_attente_de_reponse']))
      expect(service.dossiers).to include(dossier_pending_response)
      expect(service.dossiers).not_to include(dossier_pending_correction, dossier_unread_message)
    end

    it 'filters by nouveau_message' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['nouveau_message']))
      expect(service.dossiers).to include(dossier_unread_message)
      expect(service.dossiers).not_to include(dossier_pending_correction, dossier_pending_response)
    end

    it 'combines multiple alerts (OR)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['a_corriger', 'nouveau_message']))
      expect(service.dossiers).to include(dossier_pending_correction, dossier_unread_message)
      expect(service.dossiers).not_to include(dossier_pending_response)
    end
  end
end
