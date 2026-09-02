# frozen_string_literal: true

RSpec.describe Cron::SendAPIParticulierTokenExpirationNoticeJob, type: :job do
  describe 'perform' do
    let(:administrateur) { administrateurs.default }
    let(:expires_at) { 6.months.from_now }
    let(:token) { JWT.encode({ exp: expires_at.to_i }, nil, 'none') }
    let(:garbage_token) { 'azertyuiopqsdfgh' }
    let(:mailer_double) { double('mailer', deliver_later: true) }

    def published_procedure(token)
      create(:procedure, :published, :with_service,
        administrateurs: [administrateur],
        for_individual: true,
        public_type_de_champs: [{ type: :quotient_familial }],
        api_particulier_token: token)
    end

    let!(:procedure) { published_procedure(token) }

    def perform_now
      Cron::SendAPIParticulierTokenExpirationNoticeJob.perform_now
    end

    before do
      allow(AdministrateurMailer).to receive(:api_particulier_token_expiration).and_return(mailer_double)
    end

    context 'when the token expires in more than a month' do
      let(:expires_at) { 2.months.from_now }

      before { perform_now }

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when the procedure has no token' do
      let!(:procedure) { published_procedure(nil) }

      before { perform_now }

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    context 'when the token expires within a month' do
      let(:expires_at) { 3.weeks.from_now }

      before { perform_now }

      it 'sends a notification, saves notification date' do
        expect(AdministrateurMailer).to have_received(:api_particulier_token_expiration).with(administrateur, procedure)
        expect(mailer_double).to have_received(:deliver_later).once
        expect(procedure.reload.api_particulier_token_expiration_notice_sent_at).to be_within(1.second).of(Time.current)
      end
    end

    # La colonne charrie des clés API Particulier v1/v2 abandonnées, sur des
    # démarches dont les champs ont été convertis en texte : leurs administrateurs
    # n'ont rien à renouveler et ne doivent pas être dérangés.
    context 'when the procedure no longer has an API Particulier champ' do
      let!(:procedure) do
        create(:procedure, :published, administrateurs: [administrateur]).tap do
          it.api_particulier_token = garbage_token
          it.save(validate: false)
        end
      end

      before { perform_now }

      it { expect(mailer_double).not_to have_received(:deliver_later) }
    end

    # Le cas de RAILS-MGX : l'administrateur avait saisi n'importe quoi, l'appel
    # échouait pour chaque usager et personne n'était prévenu.
    context 'when the token cannot be decoded' do
      let!(:procedure) do
        published_procedure(nil).tap do
          it.api_particulier_token = garbage_token
          it.save(validate: false)
        end
      end

      it 'notifies, then reminds a month later' do
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        travel_to(2.days.from_now)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        travel_to(2.months.from_now)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).twice
      end
    end

    # Le validateur empêche de publier une démarche dont le jeton est hors service :
    # son administrateur doit savoir pourquoi, avant même la publication.
    context 'when the procedure is still a draft' do
      let!(:procedure) do
        create(:procedure, :with_service,
          administrateurs: [administrateur],
          for_individual: true,
          public_type_de_champs: [{ type: :quotient_familial }],
          api_particulier_token: nil).tap do
          it.api_particulier_token = garbage_token
          it.save(validate: false)
        end
      end

      it 'notifies, then stops reminding' do
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        travel_to(2.months.from_now)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once
      end
    end

    # Un jeton expiré ne se répare pas tout seul : tant qu'il n'est pas renouvelé,
    # les appels sont coupés, donc les relances continuent.
    context 'when the token is expired' do
      let(:expires_at) { 1.day.ago }

      it 'keeps reminding every month' do
        perform_now
        expect(mailer_double).to have_received(:deliver_later).once

        travel_to(2.months.from_now)
        perform_now
        expect(mailer_double).to have_received(:deliver_later).twice
      end
    end
  end
end
