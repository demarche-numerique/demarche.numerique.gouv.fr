# frozen_string_literal: true

describe Brevo::APIDeliveryMethod do
  include Dry::Monads[:result]

  let(:delivery) { described_class.new({}) }
  let(:mail) do
    Mail.new(from: 'no-reply@example.gouv.fr', to: 'usager@example.com', subject: 'S', 'X-DN-Mailer' => 'UserMailer.ask_for_merge').tap do |m|
      m.html_part = Mail::Part.new { content_type 'text/html; charset=UTF-8'; body '<p>B</p>' }
      m.text_part = Mail::Part.new { body 'B' }
    end
  end
  let(:api) { instance_double(Brevo::API) }

  before { allow(Brevo::API).to receive(:new).and_return(api) }

  def failure(kind, brevo_code: nil)
    Failure(Brevo::API::Error[kind, :http, 400, brevo_code, 'masked message'])
  end

  it 'stamps the Brevo message id and the date on success' do
    allow(api).to receive(:send_email).with(hash_including(to: [{ email: 'usager@example.com' }])).and_return(Success(['<1@smtp-relay.mailin.fr>']))

    delivery.deliver!(mail)

    expect(mail.message_id).to eq('1@smtp-relay.mailin.fr')
    expect(mail.date).to be_present
  end

  it 'gives each bcc recipient its own Brevo message id in EmailEvent' do
    mail.to = nil
    mail.bcc = ['a@example.com', 'b@example.com']
    allow(api).to receive(:send_email)
      .with(hash_including(messageVersions: [{ to: [{ email: 'a@example.com' }] }, { to: [{ email: 'b@example.com' }] }]))
      .and_return(Success(['<1@smtp-relay.mailin.fr>', '<2@smtp-relay.mailin.fr>']))

    delivery.deliver!(mail)
    EmailEvent.create_from_message!(mail, status: 'dispatched')

    expect(EmailEvent.where(to: ['a@example.com', 'b@example.com']).pluck(:to, :message_id)).to contain_exactly(
      ['a@example.com', '1@smtp-relay.mailin.fr'],
      ['b@example.com', '2@smtp-relay.mailin.fr']
    )
  end

  it 'treats a duplicate as already delivered' do
    allow(api).to receive(:send_email).and_return(failure(:duplicate, brevo_code: 'duplicate_request'))

    expect { delivery.deliver!(mail) }.not_to raise_error
  end

  it 'raises one exception class per failure kind' do
    {
      outage: described_class::OutageError,
      throttled: described_class::ThrottledError,
      account: described_class::AccountError,
      rejected: described_class::RejectedError,
    }.each do |kind, exception|
      allow(api).to receive(:send_email).and_return(failure(kind, brevo_code: 'some_code'))
      expect { delivery.deliver!(mail) }.to raise_error(exception, /some_code/)
    end
  end
end
