# frozen_string_literal: true

RSpec.describe Cron::SendAPIEntrepriseTokenExpirationNoticeJob, type: :job do
  describe 'perform' do
    let(:administrateur) { administrateurs(:default_admin) }
    let(:expires_at) { 6.months.from_now }
    let(:token) { JWT.encode({ exp: expires_at.to_i }, nil, 'none') }
    let!(:procedure) { create(:procedure, administrateurs: [administrateur], api_entreprise_token: token) }
    let(:mailer_double) { double('mailer', deliver_later: true) }

    def perform_now
      Cron::SendAPIEntrepriseTokenExpirationNoticeJob.perform_now
    end

    before do
      allow(AdministrateurMailer).to receive(:api_entreprise_token_expiration).and_return(mailer_double)
    end

    context 'when the token expires in more than a month' do
      let(:expires_at) { 2.months.from_now }

      before { perform_now }

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when the procedure uses the global token (no specific token)' do
      let!(:procedure) { create(:procedure, administrateurs: [administrateur], api_entreprise_token: nil) }

      before { perform_now }

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when the token expires within a month' do
      let(:expires_at) { 3.weeks.from_now }

      before { perform_now }

      it 'sends a notification, saves notification date' do
        expect(AdministrateurMailer).to have_received(:api_entreprise_token_expiration).with(administrateur, procedure)
        expect(mailer_double).to have_received(:deliver_later).once
        expect(procedure.reload.api_entreprise_token_expiration_notice_sent_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when already notified for the same window' do
      let(:expires_at) { 3.days.from_now }

      before do
        procedure.update!(api_entreprise_token_expiration_notice_sent_at: 1.day.ago)
        perform_now
      end

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when notified for previous window but now in a smaller window' do
      let(:target_date) { Time.zone.parse('2025-07-01 12:00') }
      let(:expires_at) { target_date }
      let!(:procedure) { create(:procedure, administrateurs: [administrateur], api_entreprise_token: token) }

      it 'sends a new notification when crossing into a smaller window' do
        # Notified during the 1-month window
        travel_to(target_date - 3.weeks)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        # Still in 1-month window next day: no re-send
        travel_to(target_date - 3.weeks + 1.day)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        # Crosses into 1-week window
        travel_to(target_date - 5.days)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).twice

        # Still in 1-week window next day: no re-send
        travel_to(target_date - 4.days)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).twice

        # Crosses into 1-day window
        travel_to(target_date - 12.hours)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).exactly(3).times
      end
    end
  end
end
