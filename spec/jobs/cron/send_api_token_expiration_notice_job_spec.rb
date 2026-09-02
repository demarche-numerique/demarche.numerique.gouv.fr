# frozen_string_literal: true

RSpec.describe Cron::SendAPITokenExpirationNoticeJob, type: :job do
  describe 'perform' do
    let(:administrateur) { administrateurs.default }
    let!(:token) { APIToken.generate(administrateur).first }
    let(:mailer_double) { double('mailer', deliver_later: true) }
    let(:today) { Date.new(2018, 01, 01) }

    def perform_now
      Cron::SendAPITokenExpirationNoticeJob.perform_now
    end

    before do
      travel_to(today)
      token.update!(created_at: today)
      allow(APITokenMailer).to receive(:expiration).and_return(mailer_double)
    end

    # Eternal tokens can no longer be created, but the existing ones must keep
    # falling outside of every notice window.
    context 'when the token does not expire' do
      before do
        token.update_column(:expires_at, nil)
        perform_now
      end

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when the token expires in 6 months' do
      let(:expires_at) { Date.new(2018, 06, 01) }
      before do
        token.update(expires_at:)
        perform_now
      end

      it { expect(mailer_double).not_to have_received(:deliver_later) }

      context 'when the token expires less than a month' do
        before do
          travel_to(expires_at - 1.month - 1.day)
          perform_now

          travel_to(expires_at - 1.month)
          perform_now

          travel_to(expires_at - 1.month + 1.day)
          perform_now
        end

        it do
          expect(mailer_double).to have_received(:deliver_later).once
          expect(token.reload.expiration_notices_sent_at).to match_array([expires_at - 1.month])
        end
      end

      context 'when the token expires less than a week' do
        before do
          travel_to(expires_at - 1.week)
          2.times.each { perform_now }
        end

        it { expect(mailer_double).to have_received(:deliver_later).once }
      end

      context 'when we simulate the whole sequence' do
        before do
          travel_to(expires_at - 1.month)
          2.times.each { perform_now }

          travel_to(expires_at - 1.week)
          2.times.each { perform_now }

          travel_to(expires_at - 1.day)
          2.times.each { perform_now }
        end

        it do
          expect(mailer_double).to have_received(:deliver_later).exactly(3).times
          expect(token.reload.expiration_notices_sent_at).to match_array([
            expires_at - 1.month,
            expires_at - 1.week,
            expires_at - 1.day,
          ])
        end
      end
    end
  end
end
