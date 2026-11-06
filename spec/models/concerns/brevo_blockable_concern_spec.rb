# frozen_string_literal: true

describe BrevoBlockableConcern do
  let(:user) { users.usager }
  let(:earlier) { Time.zone.parse('2026-11-02 09:05') }
  let(:between) { Time.zone.parse('2026-11-02 11:30') }
  let(:later) { Time.zone.parse('2026-11-02 14:00') }

  describe '.record_brevo_event' do
    it 'records a blocking event with its reason' do
      User.record_brevo_event(email: user.email, event: 'spam', at: earlier)

      expect(user.reload).to have_attributes(brevo_last_blocked_at: earlier, brevo_blocked_reason: 'spam', brevo_blocked_reason_at: earlier)
    end

    it 'records a blocked event without a reason' do
      User.record_brevo_event(email: user.email, event: 'blocked', at: earlier)

      expect(user.reload).to have_attributes(brevo_last_blocked_at: earlier, brevo_blocked_reason: nil, brevo_blocked_reason_at: nil)
    end

    it 'finds the user whatever the case of the email' do
      User.record_brevo_event(email: " #{user.email.upcase} ", event: 'spam', at: earlier)

      expect(user.reload.brevo_blocked_reason).to eq('spam')
    end

    it 'ignores an event that leaves the address open' do
      User.record_brevo_event(email: user.email, event: 'delivered', at: earlier)

      expect(user.reload.brevo_last_blocked_at).to be_nil
    end
  end

  describe '#record_brevo_block!' do
    it 'takes the reason of an older event received after a blocked one' do
      user.record_brevo_block!(at: later, event: 'blocked')
      user.record_brevo_block!(at: earlier, event: 'spam')

      expect(user.reload).to have_attributes(brevo_last_blocked_at: later, brevo_blocked_reason: 'spam', brevo_blocked_reason_at: earlier)
    end

    it 'keeps the latest reason when an older one arrives late' do
      user.record_brevo_block!(at: later, event: 'spam')
      user.record_brevo_block!(at: earlier, event: 'hard_bounce')

      expect(user.reload).to have_attributes(brevo_last_blocked_at: later, brevo_blocked_reason: 'spam', brevo_blocked_reason_at: later)
    end

    it 'takes a newer reason received after a later blocked event' do
      user.record_brevo_block!(at: earlier, event: 'spam')
      user.record_brevo_block!(at: later, event: 'blocked')
      user.record_brevo_block!(at: between, event: 'hard_bounce')

      expect(user.reload).to have_attributes(brevo_last_blocked_at: later, brevo_blocked_reason: 'hard_bounce', brevo_blocked_reason_at: between)
    end

    it 'keeps the latest blocked event when an older one arrives late' do
      user.record_brevo_block!(at: later, event: 'blocked')
      user.record_brevo_block!(at: earlier, event: 'blocked')

      expect(user.reload.brevo_last_blocked_at).to eq(later)
    end

    it 'unsubscribes the user on an unsubscription or a spam complaint' do
      other = users.instructeur
      user.record_brevo_block!(at: earlier, event: 'unsubscribed')
      other.record_brevo_block!(at: earlier, event: 'spam')

      expect([user.reload.email_unsubscribed, other.reload.email_unsubscribed]).to eq([true, true])
    end

    it 'keeps the user subscribed on a hard bounce' do
      user.record_brevo_block!(at: earlier, event: 'hard_bounce')

      expect(user.reload.email_unsubscribed).to be(false)
    end
  end

  describe '#brevo_blocked?' do
    it 'is false for an address Brevo never blocked' do
      expect(user.brevo_blocked?).to be(false)
    end

    it 'is true once Brevo blocked the address' do
      user.record_brevo_block!(at: earlier, event: 'spam')

      expect(user.reload.brevo_blocked?).to be(true)
    end

    context 'once unblocked' do
      before { user.update_columns(brevo_unblocked_at: between) }

      it 'is false for a block from before the unblock' do
        user.record_brevo_block!(at: earlier, event: 'spam')

        expect(user.reload.brevo_blocked?).to be(false)
      end

      it 'is true for a block from after the unblock' do
        user.record_brevo_block!(at: earlier, event: 'spam')
        user.record_brevo_block!(at: later, event: 'blocked')

        expect(user.reload.brevo_blocked?).to be(true)
      end
    end
  end
end
