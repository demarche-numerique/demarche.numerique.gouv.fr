# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe T20260923BackfillUserSessionExpiryTask do
    describe '#process' do
      subject(:process) { described_class.process(user_session) }

      let(:user) { create(:user) }
      let(:user_session) { user.open_user_session!('a browser') }

      before { user_session.update_column(:expires_at, nil) }

      it 'counts the deadline from when the session opened, not from now' do
        expect { process }
          .to change { user_session.reload.expires_at }
          .from(nil)
          .to(be_within(1.minute).of(user_session.created_at + User::USAGER_SESSION_MAX_LIFETIME))
      end

      it 'gives an agent the deadline of its own role' do
        instructeur = create(:instructeur)
        row = instructeur.user.open_user_session!('a browser')
        row.update_column(:expires_at, nil)

        described_class.process(row)

        expect(row.reload.expires_at)
          .to be_within(1.minute).of(row.created_at + TrustedDeviceConcern::TRUSTED_DEVICE_PERIOD)
      end

      # A row whose account is gone: the cascade will take it, this must not raise.
      it 'leaves a row without an account alone' do
        user_session.update_column(:sessionable_id, User.maximum(:id).to_i + 1)

        expect { process }.not_to raise_error
      end
    end

    describe '#collection' do
      it 'takes only the rows that carry no deadline' do
        user = create(:user)
        bounded = user.open_user_session!('a browser')
        unbounded = user.open_user_session!('another browser')
        unbounded.update_column(:expires_at, nil)

        expect(described_class.new.collection).to include(unbounded)
        expect(described_class.new.collection).not_to include(bounded)
      end
    end
  end
end
