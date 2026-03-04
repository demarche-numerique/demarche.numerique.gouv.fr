# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CrispCreateConversationJob, type: :job do
  let(:api) { instance_double(Crisp::APIService) }
  let(:user) { nil }
  let(:email) { user&.email || 'test@domain.com' }
  let(:subject_text) { 'Test Subject' }
  let(:text) { 'Test message content' }
  let(:tags) { ['test tag'] }
  let(:question_type) { 'lost_user' }
  let(:phone) { nil }
  let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:148.0) Gecko/20100101 Firefox/148.0" }
  let(:contact_form) { create(:contact_form, email:, user:, subject: subject_text, text:, tags:, phone:, question_type:, user_agent:) }
  let(:session_id) { 'session_test-123-456' }

  before do
    allow(Crisp::APIService).to receive(:new).and_return(api)
  end

  describe '#perform' do
    subject { described_class.perform_now(contact_form) }

    context 'cas général - succès complet' do
      before do
        allow(api).to receive(:create_conversation)
          .and_return(Dry::Monads::Success(data: { session_id: session_id }))

        allow(api).to receive(:send_message)
          .and_return(Dry::Monads::Success({}))

        allow(api).to receive(:update_conversation_meta)
          .and_return(Dry::Monads::Success({}))
      end

      it 'create conversation and message, destroy contact form' do
        subject

        expect(api).to have_received(:create_conversation)

        expect(api).to have_received(:send_message).with(
          session_id: session_id,
          body: hash_including(
            type: 'text',
            from: 'user',
            origin: 'email',
            content: text,
            fingerprint: contact_form.id,
            user: { type: 'participant' }
          )
        )

        expect(api).to have_received(:update_conversation_meta).with(
          session_id: session_id,
          body: hash_including(
            email: email,
            nickname: 'Test',
            subject: subject_text,
            segments: ['test tag', 'contact form', question_type],
            device: { system: { useragent: user_agent, os: { name: "macOS", version: "10.15" }, browser: { name: "Firefox", major: "148", version: "148.0" } } }
          )
        )

        expect(contact_form).to be_destroyed
      end

      context 'user identifié' do
        let(:user) { create(:user) }

        it 'merge segments' do
          subject

          expect(api).to have_received(:update_conversation_meta).with(
            session_id: session_id,
            body: hash_including(
              email: user.email,
              segments: ['usager', 'test tag', 'contact form', question_type]
            )
          )
        end
      end
    end

    context 'avec pièce jointe saine' do
      before do
        file = fixture_file_upload('spec/fixtures/files/white.png', 'image/png')
        contact_form.piece_jointe.attach(file)

        allow_any_instance_of(ActiveStorage::Blob).to receive(:virus_scanner)
          .and_return(double('VirusScanner', pending?: false, safe?: true))

        allow(api).to receive(:create_conversation)
          .and_return(Dry::Monads::Success(data: { session_id: session_id }))

        allow(api).to receive(:send_message)
          .and_return(Dry::Monads::Success({}))

        allow(api).to receive(:update_conversation_meta)
          .and_return(Dry::Monads::Success({}))
      end

      it 'envoie deux messages (texte et fichier)' do
        subject

        expect(api).to have_received(:send_message).twice

        # Vérifier le message de type fichier
        expect(api).to have_received(:send_message).with(
          session_id: session_id,
          body: hash_including(
            type: 'file',
            from: 'user',
            origin: 'email',
            content: hash_including(
              name: 'white.png',
              type: 'image/png'
            )
          )
        )
      end
    end

    context 'when the file has not been scanned yet' do
      before do
        file = fixture_file_upload('spec/fixtures/files/white.png', 'image/png')
        contact_form.piece_jointe.attach(file)

        allow_any_instance_of(ActiveStorage::Blob).to receive(:virus_scanner).and_return(double('VirusScanner', pending?: true, safe?: false))
      end

      it 'reenqueues job' do
        expect { subject }.to have_enqueued_job(described_class).with(contact_form)
      end
    end

    context 'conversation creation error' do
      before do
        allow(api).to receive(:create_conversation)
          .and_return(Dry::Monads::Failure(error: 'API Error'))
      end

      it 'reenqueues job so it will retry later' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(5)

        expect { subject }.to have_enqueued_job(described_class)
        expect(contact_form).not_to be_destroyed
      end

      it 'destroy contact form when max executions is reached' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(16)

        expect { subject }.to have_enqueued_job(described_class)
        expect(contact_form).to be_destroyed
      end
    end

    context 'cas d’erreur - échec d’envoi de message' do
      before do
        allow(api).to receive(:create_conversation)
          .and_return(Dry::Monads::Success(data: { session_id: session_id }))

        allow(api).to receive(:send_message)
          .and_return(Dry::Monads::Failure(error: 'Message send failed'))
      end

      it 'reenqueues job for retry' do
        expect { subject }.to have_enqueued_job(described_class)
      end
    end

    context 'when email or subject contains test patterns' do
      let(:email) { 'user-testing@example.com' }

      before do
        allow(api).to receive(:create_conversation)
      end

      it 'ignores contact form and aborts job execution' do
        subject

        expect(api).not_to have_received(:create_conversation)
        expect(contact_form).to be_destroyed
      end
    end

    context 'when user agent contains test patterns' do
      let(:user_agent) { 'ywh' }

      before do
        allow(api).to receive(:create_conversation)
      end

      it 'ignores contact form and aborts job execution' do
        subject

        expect(api).not_to have_received(:create_conversation)
        expect(contact_form).to be_destroyed
      end
    end
  end
end
