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
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['en_construction']))
      expect(service.dossiers).to include(en_construction)
      expect(service.dossiers).not_to include(brouillon, en_instruction, accepte)
    end

    it 'filters by multiple states (OR)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['brouillon', 'en_construction']))
      expect(service.dossiers).to include(brouillon, en_construction)
      expect(service.dossiers).not_to include(en_instruction, accepte)
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

  describe '#total_count' do
    it 'returns the number of filtered dossiers' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['brouillon']))
      expect(service.total_count).to eq(service.dossiers.count)
    end

    it 'memoizes the count so repeated access does not re-query (read twice per render)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service).to receive(:dossiers).once.and_call_original
      3.times { service.total_count }
    end
  end

  describe '#active?' do
    it 'is false when no filter is applied' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.active?).to be(false)
    end

    it 'ignores search as an active filter' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(search: 'foo'))
      expect(service.active?).to be(false)
    end

    it 'is true when a filter other than search is applied' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['en_construction']))
      expect(service.active?).to be(true)
    end
  end

  describe '#counts' do
    let!(:dossier_depose_corriger) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_depose_nothing) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_accepte) { create(:dossier, :accepte, user: user) }

    before do
      create(:dossier_correction, dossier: dossier_depose_corriger)
    end

    it 'returns counts for states (ignoring state filter itself)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['en_construction']))
      expect(service.counts[:states]['en_construction']).to eq(4)
      expect(service.counts[:states]['accepte']).to eq(1)
    end

    it 'returns counts for alerts (contextualized by state filter)' do
      Flipper.enable_actor(:usager_dossiers_alert_filters, user)
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['en_construction']))
      expect(service.counts[:alerts]['a_corriger']).to eq(1)
    end

    it 'returns shared_with_me count' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.counts[:shared_with_me]).to eq(1)
    end

    it 'bounds every alert subquery to the user dossiers instead of scanning the whole table' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)

      described_class::ALERT_SCOPES.each_value do |scope_name|
        sql = service.send(:bounded_alert_subquery, scope_name).to_sql
        expect(sql).to include(%("dossiers"."user_id" = #{user.id}))
      end
    end

    it 'memoizes counts so repeated access does not recompute (filter panel reads them many times)' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service).to receive(:count_states).once.and_call_original
      3.times { service.counts }
    end

    it 'counts only the user own alerts, not other users matching dossiers' do
      Flipper.enable_actor(:usager_dossiers_alert_filters, user)
      other_dossier_with_correction = create(:dossier, :en_construction)
      create(:dossier_correction, dossier: other_dossier_with_correction)

      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.counts[:alerts]['a_corriger']).to eq(1)
    end

    context 'when the alert filters feature is disabled (default)' do
      it 'exposes alerts_enabled? as false' do
        expect(service.alerts_enabled?).to be(false)
      end

      it 'returns zero for every alert without running the alert subqueries' do
        expect(service).not_to receive(:bounded_alert_subquery)
        expect(service.counts[:alerts].values).to all(eq(0))
      end

      it 'ignores alert params forged via the URL (no alert filter tag)' do
        service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['a_corriger']))
        expect(service.active_filter_tags.map { it[:group] }).not_to include(:alert)
      end

      it 'does not filter dossiers by a forged alert param' do
        service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['a_corriger']))
        expect(service.dossiers).to include(dossier_depose_nothing)
      end
    end

    context 'when the alert filters feature is enabled' do
      before { Flipper.enable_actor(:usager_dossiers_alert_filters, user) }

      it 'exposes alerts_enabled? as true' do
        expect(service.alerts_enabled?).to be(true)
      end
    end

    it 'runs a constant number of queries regardless of dossier volume (no N+1)' do
      queries_for = lambda do |volume|
        owner = create(:user)
        create_list(:dossier, volume, :en_construction, user: owner)
        service = described_class.new(user: owner, params: ActionController::Parameters.new)
        count = 0
        counter = lambda do |_name, _started, _finished, _id, payload|
          count += 1 unless %w[SCHEMA TRANSACTION CACHE].include?(payload[:name])
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { service.counts }
        count
      end

      expect(queries_for.call(5)).to eq(queries_for.call(1))
    end
  end

  describe '#active_filter_tags' do
    let(:procedure) { create(:procedure, libelle: 'Demande de subvention') }
    let!(:dossier_in_procedure) { create(:dossier, :en_construction, user: user, procedure: procedure) }

    it 'returns one tag per active filter value' do
      Flipper.enable_actor(:usager_dossiers_alert_filters, user)
      service = described_class.new(user: user, params: ActionController::Parameters.new(
        procedure_id: procedure.id.to_s,
        state: ['en_construction', 'en_instruction'],
        alert: ['a_corriger']
      ))
      keys = service.active_filter_tags.map { |t| [t[:group], t[:value]] }
      expect(keys).to contain_exactly(
        [:procedure_id, procedure.id.to_s],
        [:state, 'en_construction'],
        [:state, 'en_instruction'],
        [:alert, 'a_corriger']
      )
    end

    it 'returns an empty list when no filter is active' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.active_filter_tags).to eq([])
    end

    context 'when procedure_id targets a procedure the user has no dossier in' do
      let!(:foreign_procedure) { create(:procedure, libelle: 'Démarche confidentielle') }

      it 'does not leak the procedure libelle' do
        service = described_class.new(user: user, params: ActionController::Parameters.new(procedure_id: foreign_procedure.id.to_s))
        labels = service.active_filter_tags.map { |t| t[:label] }
        expect(labels).not_to include('Démarche confidentielle')
      end
    end

    context 'when procedure_id targets a procedure the user has a dossier in' do
      let!(:own_procedure_dossier) { create(:dossier, :en_construction, user: user, procedure: create(:procedure, libelle: 'Ma démarche')) }

      it 'shows the procedure libelle' do
        service = described_class.new(user: user, params: ActionController::Parameters.new(procedure_id: own_procedure_dossier.procedure.id.to_s))
        labels = service.active_filter_tags.map { |t| t[:label] }
        expect(labels).to include('Ma démarche')
      end
    end

    it 'labels date filters with a human readable sentence' do
      I18n.with_locale(:fr) do
        service = described_class.new(user: user, params: ActionController::Parameters.new(
          from_created_at_date: '2026-06-24',
          from_depose_at_date: '2026-06-24'
        ))
        labels = service.active_filter_tags.map { |t| t[:label] }
        expect(labels).to contain_exactly('Créé depuis le 24/06/2026', 'Déposé depuis le 24/06/2026')
      end
    end
  end

  describe '#dossiers preloading' do
    def count_queries
      count = 0
      counter = lambda do |_name, _started, _finished, _id, payload|
        next if %w[SCHEMA TRANSACTION CACHE].include?(payload[:name])
        count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { yield }
      count
    end

    def touch_partial_associations(dossiers)
      dossiers.each do |d|
        d.procedure.libelle
        d.procedure.path
        d.invites.to_a
        d.transfer
        d.pending_correction?
        d.pending_response?
        d.user_email_for(:display)
      end
    end

    it 'keeps the query count constant when listing more dossiers (no N+1)' do
      isolated_user = create(:user)
      queries_for = lambda do |n|
        Dossier.where(user: isolated_user).destroy_all
        n.times { create(:dossier, :en_construction, user: isolated_user) }
        service = described_class.new(user: isolated_user, params: ActionController::Parameters.new)
        count_queries { touch_partial_associations(service.dossiers) }
      end

      expect(queries_for.call(5)).to eq(queries_for.call(1))
    end
  end

  describe '#dossiers preloading of unread_commentaires_for_user' do
    let(:user) { create(:user) }
    let(:service) { described_class.new(user:, params: ActionController::Parameters.new) }

    before do
      dossier = create(:dossier, :en_construction, user:)
      create(:commentaire, dossier:, instructeur: create(:instructeur), seen_by_recipient_at: nil)
    end

    it 'preloads unread_commentaires_for_user to avoid N+1 in the list' do
      dossiers = service.dossiers.to_a

      expect(dossiers).to be_present
      expect(dossiers.map { it.unread_commentaires_for_user.loaded? }).to all(be(true))
    end
  end

  describe '#dossiers with alert filter' do
    let!(:dossier_pending_correction) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_pending_response) { create(:dossier, :en_construction, user: user) }
    let!(:dossier_unread_message) { create(:dossier, :en_construction, user: user) }

    before do
      Flipper.enable_actor(:usager_dossiers_alert_filters, user)
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

  describe 'hidden decision (accusé de lecture)' do
    let(:procedure_al) { create(:procedure, :accuse_lecture) }
    let!(:masked) { create(:dossier, :accepte, user: user, procedure: procedure_al, accuse_lecture_agreement_at: nil) }
    let!(:acknowledged) { create(:dossier, :accepte, user: user, procedure: procedure_al, accuse_lecture_agreement_at: Time.current) }

    it 'excludes decision-masked dossiers when filtering on a terminé state' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['accepte']))
      expect(service.dossiers).to include(acknowledged)
      expect(service.dossiers).not_to include(masked)
    end

    it 'does not count decision-masked dossiers in the terminé state count' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.counts[:states]['accepte']).to eq(1)
    end

    it 'still lists masked dossiers when no state filter is applied' do
      service = described_class.new(user: user, params: ActionController::Parameters.new)
      expect(service.dossiers).to include(masked, acknowledged)
    end
  end

  describe 'param validation' do
    it 'ignores an unknown alert value in active_filter_tags' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(alert: ['nimportequoi']))
      expect(service.active_filter_tags.map { |t| t[:group] }).not_to include(:alert)
    end

    it 'ignores an unknown state value in active_filter_tags' do
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['nimportequoi']))
      expect(service.active_filter_tags.map { |t| t[:group] }).not_to include(:state)
    end

    it 'does not apply an unknown state to the query' do
      own = create(:dossier, :en_construction, user: user)
      service = described_class.new(user: user, params: ActionController::Parameters.new(state: ['nimportequoi']))
      expect(service.dossiers).to include(own)
    end
  end
end
