# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe T20260923BackfillUserSessionExpiryTask do
    def backfill(*user_sessions)
      described_class.process(UserSession.where(id: user_sessions.map(&:id)))
    end

    describe '#process' do
      let(:user) { create(:user) }
      let(:user_session) { user.open_user_session!('a browser') }

      before { user_session.update_column(:expires_at, nil) }

      it 'counts the deadline from when the session opened, not from now' do
        expect { backfill(user_session) }
          .to change { user_session.reload.expires_at }
          .from(nil)
          .to(be_within(1.minute).of(user_session.created_at + User::USAGER_SESSION_MAX_LIFETIME))
      end

      # A calendar month, the one the trusted device is counted in -- not the
      # average month `1.month.to_i` would give.
      it 'gives an agent the deadline of its own role' do
        instructeur = create(:instructeur)
        row = instructeur.user.open_user_session!('a browser')
        row.update_column(:expires_at, nil)

        backfill(row)

        expect(row.reload.expires_at)
          .to be_within(1.minute).of(row.created_at + TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD)
      end

      # A row whose account is gone: the cascade will take it, this must not raise.
      it 'leaves a row without an account alone' do
        user_session.update_column(:sessionable_id, User.maximum(:id).to_i + 1)

        expect { backfill(user_session) }.not_to change { user_session.reload.expires_at }
      end

      # Grouped by deadline, so a batch of thousands is a handful of statements
      # rather than one per row.
      # `session_max_lifetime` asks for the gestionnaire, the one role User does
      # not eager load: once for the batch, not once per account.
      it 'does not ask for the gestionnaire once per account' do
        others = Array.new(3) { create(:user).open_user_session!('a browser') }
        others.each { it.update_column(:expires_at, nil) }

        gestionnaire_queries = count_queries(matching: /"gestionnaires"/) { backfill(*others) }

        expect(gestionnaire_queries).to eq(1)
      end

      it 'writes one statement per distinct deadline, whatever the batch size' do
        rows = Array.new(3) { user.open_user_session!('a browser') }
        rows.each { it.update_column(:expires_at, nil) }
        agent_row = create(:instructeur).user.open_user_session!('a browser')
        agent_row.update_column(:expires_at, nil)

        updates = count_queries(matching: /\AUPDATE/) { backfill(*rows, agent_row) }

        expect(updates).to eq(2)
      end
    end

    describe '#collection' do
      it 'takes only the rows that carry no deadline' do
        user = create(:user)
        bounded = user.open_user_session!('a browser')
        unbounded = user.open_user_session!('another browser')
        unbounded.update_column(:expires_at, nil)

        ids = described_class.new.collection.flat_map { it.pluck(:id) }

        expect(ids).to include(unbounded.id)
        expect(ids).not_to include(bounded.id)
      end
    end
  end
end
