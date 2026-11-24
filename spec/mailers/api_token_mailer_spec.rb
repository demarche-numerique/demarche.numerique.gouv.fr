# frozen_string_literal: true

RSpec.describe APITokenMailer, type: :mailer do
  let(:administrateur) { administrateurs.blank }
  let(:user) { administrateur.user }

  describe '#expiration' do
    let(:api_token) { APIToken.generate(administrateur, name: 'Prod').first }

    subject(:mail) { described_class.expiration(api_token) }

    it 'tells the owner to duplicate the token before it expires' do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("Votre jeton d’API « Prod » expire le #{I18n.l(api_token.expires_at, format: :long)}")
      expect(mail.body.decoded).to include('Dupliquez-le depuis votre profil')
    end

    context 'with a warned co-administrateur' do
      subject(:mail) { described_class.expiration(api_token, ['collegue@exemple.fr']) }

      it { expect(mail.body.decoded).to include('Nous avons aussi prévenu cet administrateur de vos démarches : collegue@exemple.fr.') }
    end
  end

  describe '#expiration_for_co_administrator' do
    let(:owner) { administrateurs.default }
    let(:api_token) { APIToken.generate(owner, name: 'Prod', allowed_procedure_ids: [procedures.individual.id]).first }

    before { procedures.individual.administrateurs << administrateur }

    subject(:mail) { described_class.expiration_for_co_administrator(api_token, administrateur, [administrateur.email, 'collegue@exemple.fr']) }

    it 'tells the co-administrateur whose token expires, how to keep the access, and who else was told' do
      expect(mail.to).to eq([user.email])
      expect(mail.body.decoded).to include('S’il sert à votre équipe, dupliquez-le depuis votre profil')
      expect(mail.body.decoded).to include("Ont aussi reçu ce message : #{owner.email} et collegue@exemple.fr.")
    end
  end

  describe '#becomes_expirable' do
    # The cap itself, so the date is always within the create validations, and
    # a fixed one would silently expire. It is also what the backfill passes.
    let(:expires_on) { APIToken.max_expires_at }
    let(:api_tokens) do
      [
        APIToken.generate(administrateur, expires_at: expires_on).first,
        APIToken.generate(administrateur, expires_at: expires_on).first,
      ]
    end

    subject(:mail) { described_class.becomes_expirable(user, api_tokens, expires_on) }

    it 'is addressed to the administrateur' do
      expect(mail.to).to eq([user.email])
    end

    it 'announces the deadline in the subject' do
      expect(mail.subject).to include('expire')
    end

    it 'lists every token and the deadline' do
      body = mail.body.encoded

      api_tokens.each { |api_token| expect(body).to include(api_token.name) }
      expect(body).to include(I18n.l(expires_on, format: :long))
    end

    # An admin who unsubscribed would otherwise learn about the deadline the day
    # their integration breaks — the recurring notices included, which are the
    # ones that land while there is still time to act.
    it 'is critical, like every mail announcing the end of an API access' do
      expect(described_class.critical_email?('becomes_expirable')).to be true
      expect(described_class.critical_email?('expiration')).to be true
    end

    it 'is delivered on the priority queue' do
      expect { mail.deliver_later }
        .to have_enqueued_job.on_queue(Rails.application.config.action_mailer.deliver_later_queue_name)
    end
  end
end
