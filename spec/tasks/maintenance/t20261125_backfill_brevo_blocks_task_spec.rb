# frozen_string_literal: true

module Maintenance
  RSpec.describe T20261125BackfillBrevoBlocksTask do
    include Dry::Monads[:result]

    let(:task) { described_class.new }
    let(:brevo) { instance_double(Brevo::API) }

    before do
      allow(Brevo::API).to receive(:new).and_return(brevo)
      allow(brevo).to receive(:blocked_contacts).and_return(Success([]))
      allow(task).to receive(:sleep)
    end

    describe '#enumerator_builder' do
      let(:oldest) { [{ email: 'a@example.com', at: Time.zone.parse('2026-11-02 09:05') }] }
      let(:newer) { [{ email: 'b@example.com' }] }

      before { travel_to(Time.zone.parse('2026-11-04 12:00')) }

      it 'reads the list day by day, from the day before the oldest block to yesterday, one page a second' do
        allow(brevo).to receive(:blocked_contacts).with(offset: 0, limit: 1).and_return(Success(oldest))
        allow(brevo).to receive(:blocked_contacts).with(day: Date.new(2026, 11, 2), offset: 0).and_return(Success(oldest))
        allow(brevo).to receive(:blocked_contacts).with(day: Date.new(2026, 11, 3), offset: 0).and_return(Success(newer))

        expect(task.enumerator_builder(cursor: nil).to_a).to eq([
          [[], '2026-11-02/0'],
          [oldest, '2026-11-03/0'],
          [newer, '2026-11-04/0'],
        ])
        expect(brevo).not_to have_received(:blocked_contacts).with(day: Date.new(2026, 11, 4), offset: 0)
        expect(task).to have_received(:sleep).with(1.second).exactly(3).times
      end

      it 'stays on a day while its pages are full' do
        stub_const('Brevo::API::BLOCKED_CONTACTS_MAX_LIMIT', 1)
        allow(brevo).to receive(:blocked_contacts).with(day: Date.new(2026, 11, 3), offset: 0).and_return(Success(oldest))
        allow(brevo).to receive(:blocked_contacts).with(day: Date.new(2026, 11, 3), offset: 1).and_return(Success(newer))

        expect(task.enumerator_builder(cursor: '2026-11-03/0').to_a).to eq([[oldest, '2026-11-03/1'], [newer, '2026-11-03/2'], [[], '2026-11-04/0']])
      end

      it 'resumes from the cursor' do
        allow(brevo).to receive(:blocked_contacts).with(day: Date.new(2026, 11, 3), offset: 1).and_return(Success(newer))

        expect(task.enumerator_builder(cursor: '2026-11-03/1').to_a).to eq([[newer, '2026-11-04/0']])
      end

      it 'reads nothing when Brevo blocks no address' do
        expect(task.enumerator_builder(cursor: nil).to_a).to eq([])
      end

      it 'stops on a Brevo failure, to resume from the last page read' do
        allow(brevo).to receive(:blocked_contacts).and_return(Failure(Brevo::API::Error[:throttled, :http, 429, 'too_many_requests', 'Rate limit']))

        expect { task.enumerator_builder(cursor: '2026-11-03/1').first }
          .to raise_error(RuntimeError, 'Brevo blocked contacts {"day":"2026-11-03","offset":1}: throttled HTTP 429 too_many_requests Rate limit')
      end
    end

    describe '#process' do
      it 'records each block, and nothing for a contact without event' do
        user, other = users.usager, users.instructeur
        at = Time.zone.parse('2026-11-02 09:05')

        task.process([{ email: user.email, event: 'hard_bounce', at: }, { email: other.email, event: nil, at: }])

        expect(user.reload).to have_attributes(brevo_last_blocked_at: at, brevo_blocked_reason: 'hard_bounce')
        expect(other.reload).to have_attributes(brevo_last_blocked_at: nil, email_unsubscribed: false)
      end
    end
  end
end
