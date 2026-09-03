# frozen_string_literal: true

RSpec.describe APITokenMailer, type: :mailer do
  let(:administrateur) { administrateurs.blank }
  let(:user) { administrateur.user }

  describe '#becomes_expirable' do
    let(:expires_on) { Date.new(2027, 8, 31) }
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
