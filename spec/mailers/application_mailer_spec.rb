# frozen_string_literal: true

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'dealing with invalid emails' do
    let(:dossier) { create(:dossier, procedure: procedures.individual) }
    subject { DossierMailer.with(dossier:).notify_new_draft }

    describe 'invalid emails are not sent' do
      before do
        allow_any_instance_of(DossierMailer)
          .to receive(:notify_new_draft)
          .and_raise(delivery_error)
      end

      context 'when the server handles invalid emails with Net::SMTPSyntaxError' do
        let(:delivery_error) { Net::SMTPSyntaxError.new('400 unexpected recipients: want atleast 1, got 0') }
        it { expect(subject.message).to be_an_instance_of(ActionMailer::Base::NullMail) }
      end

      context 'when the server handles invalid emails with Net::SMTPServerBusy' do
        let(:delivery_error) { Net::SMTPServerBusy.new('400 unexpected recipients: want atleast 1, got 0') }
        it { expect(subject.message).to be_an_instance_of(ActionMailer::Base::NullMail) }
      end
    end

    describe 'valid emails are sent' do
      it { expect(subject.message).not_to be_an_instance_of(ActionMailer::Base::NullMail) }
    end
  end

  describe 'EmailDeliveryObserver is invoked' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user, email: "your@email.com") }

    before { freeze_time }

    it 'creates a new EmailEvent record with the correct information' do
      expect { UserMailer.ask_for_merge(user1, user2.email).deliver_now }.to change { EmailEvent.count }.by(2)
      event = EmailEvent.last
      expect(EmailEvent.first.status).to eq('pending')

      expect(event.to).to eq("your@email.com")
      expect(event.method).to eq("test")
      expect(event.subject).to eq('Fusion de compte')
      expect(event.processed_at).to eq(Time.current)
      expect(event.status).to eq('dispatched')
    end
  end

  context 'EmailDeliveringInterceptor is invoked' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user, email: "your@email.com") }

    context "when there is an error and email are not sent" do
      subject { UserMailer.ask_for_merge(user1, user2.email) }

      before do
        allow_any_instance_of(Mail::Message)
          .to receive(:do_delivery)
          .and_raise(delivery_error)
      end

      context "smtp server busy" do
        let(:delivery_error) { Net::SMTPServerBusy.new('451 4.7.500 Server busy') }

        it "catches the smtp error" do
          expect { subject.deliver_now }.not_to raise_error
          expect(EmailEvent.pending.count).to eq(1)
        end
      end

      context "brevo rejects the payload" do
        let(:delivery_error) { Brevo::APIDeliveryMethod::RejectedError.new(Brevo::API::Error[:rejected, :http, 400, 'invalid_parameter', 'email [email] is not valid in to']) }

        it "records the error and does not retry" do
          allow(Sentry).to receive(:capture_exception)

          expect { subject.deliver_now }.not_to raise_error
          expect(EmailEvent.dispatch_error.exists?(to: 'your@email.com')).to be(true)
          expect(Sentry).to have_received(:capture_exception).with(delivery_error)
        end
      end

      context "does not catches other error" do
        let(:delivery_error) { Net::OpenTimeout.new }

        it "re-raise an error and creates an event" do
          expect { subject.deliver_now }.to raise_error(Net::OpenTimeout)
          expect(EmailEvent.pending.count).to eq(1)
        end
      end
    end
  end
end
