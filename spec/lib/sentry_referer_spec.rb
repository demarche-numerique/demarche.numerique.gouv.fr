# frozen_string_literal: true

describe SentryReferer do
  let(:page) { 'http://test.host/commencer/integration-eae' }
  let(:event) { Sentry::ErrorEvent.new(configuration: Sentry.configuration) }

  # the request that follows a prefill link
  def after(referer, event)
    event.rack_env = Rack::MockRequest.env_for("#{page}/sign_in", { 'HTTP_REFERER' => referer }.compact)
    event
  end

  describe '.scrub' do
    it 'keeps the address of the referrer and drops its parameters' do
      scrubbed = described_class.scrub(after("#{page}?champ_x=Externe&identite_nom=Martin", event))

      expect(scrubbed.request.headers).to include('Referer' => page)
    end

    it 'leaves a request without referrer, and an event without request, as they are' do
      expect(described_class.scrub(after(nil, event)).request.headers).not_to have_key('Referer')
      expect(described_class.scrub(Sentry::ErrorEvent.new(configuration: Sentry.configuration)).request).to be_nil
    end
  end

  # No DSN in test: the client runs the hooks and skips the transport.
  describe 'wiring' do
    it 'scrubs an error event' do
      sent = Sentry.get_current_client.send_event(after("#{page}?identite_nom=Martin", event), { exception: RuntimeError.new('boom') })

      expect(sent.request.headers).to include('Referer' => page)
    end

    it 'scrubs a transaction event, which never reaches before_send' do
      transaction = Sentry::Transaction.new(name: 'Users::CommencerController#sign_in', op: 'http.server')
      transaction.finish
      transaction_event = after("#{page}?identite_nom=Martin", Sentry::TransactionEvent.new(configuration: Sentry.configuration, transaction:))

      sent = Sentry.get_current_client.send_event(transaction_event)

      expect(sent.request.headers).to include('Referer' => page)
    end
  end
end
