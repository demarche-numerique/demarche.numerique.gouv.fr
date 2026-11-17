# frozen_string_literal: true

RSpec.describe InviteMailer, type: :mailer do
  let(:deliver) { subject.deliver_now }
  subject { InviteMailer.invite_user(invite) }

  describe '.invite_user' do
    let(:invite) { create(:invite, user: create(:user)) }

    it 'renders the translated body' do
      body = subject.body.decoded
      expect(body).to include("L’utilisateur #{invite.email_sender} souhaite")
      expect(body).to include("merci de suivre ce lien : <a href=")
      expect(body).not_to include('translation missing')
    end

    it 'creates a target_user_link' do
      expect { deliver }
        .to change { TargetedUserLink.where(target_model: invite, user: invite.user).count }
        .from(0).to(1)
    end

    context 'when it fails' do
      it 'creates only one target_user_link' do
         send_mail_values = [:raise, true]
         allow_any_instance_of(InviteMailer).to receive(:send_mail) do
           v = send_mail_values.shift
           v == :raise ? raise("boom") : v
         end

         begin
           subject.body
         rescue => e
           nil
         end

         subject.body
         expect(TargetedUserLink.where(target_model: invite, user: invite.user).count).to eq(1)
       end
    end

    context 'without SafeMailer configured' do
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(nil) }
    end

    context 'with SafeMailer configured' do
      let(:forced_delivery_method) { :kikoo }
      before { allow(SafeMailer).to receive(:forced_delivery_method).and_return(forced_delivery_method) }
      it { expect(subject[BalancerDeliveryMethod::FORCE_DELIVERY_METHOD_HEADER]&.value).to eq(forced_delivery_method.to_s) }
    end

    context 'when perform_later is called' do
      it 'enqueues email in default queue for high priority delivery' do
        expect { invite }.to have_enqueued_job.on_queue(Rails.application.config.action_mailer.deliver_later_queue_name)
      end
    end

    context 'message contains malicious link' do
      let(:invite) { create(:invite, user: create(:user), message: "Coucou\n<a href=\"https://malicious.site\">trusted anchor</a>") }
      it 'sanitize message' do
        expect(subject.body.decoded).to match(%r{<p>Coucou\s+<br />trusted anchor</p>})
      end
    end
  end

  describe '.invite_guest' do
    subject { InviteMailer.invite_guest(invite) }
    let(:invite) { create(:invite, user: nil, email: 'kikoo@lol.fr') }

    it 'renders the translated body' do
      body = subject.body.decoded
      expect(body).to include("L’utilisateur #{invite.email_sender} souhaite")
      expect(body).to include("<strong>#{invite.dossier.procedure.libelle}</strong>")
      expect(body).to include("l’adresse électronique kikoo@lol.fr sur <a href=")
      expect(body).not_to include('translation missing')
    end

    it 'creates a target_user_link' do
      expect { deliver }
        .to change { TargetedUserLink.where(target_model: invite, user: nil).count }
        .from(0).to(1)
    end

    context 'when an avis exists with same id' do
      let(:avis) { create(:avis) }
      let(:invite) { create(:invite, id: avis.id, user: nil, email: 'kikoo@lol.fr') }

      it 'associate the TargetedUserLink to the good model [does not search by id only]' do
        link_on_avis_with_same_id = create(:targeted_user_link, target_model: avis, target_context: TargetedUserLink.target_contexts[:avis])
        deliver
        expect(invite.targeted_user_link).not_to eq(link_on_avis_with_same_id)
      end
    end

    context 'when it fails' do
      it 'creates only one target_user_link' do
         send_mail_values = [:raise, true]
         allow_any_instance_of(InviteMailer).to receive(:send_mail) do
           v = send_mail_values.shift
           v == :raise ? raise("boom") : v
         end

         begin
           subject.body
         rescue => e
           nil
         end

         subject.body
         expect(TargetedUserLink.where(target_model: invite, user: invite.user).count).to eq(1)
       end
    end

    context 'when perform_later is called' do
      it 'enqueues email in default queue for high priority delivery' do
        expect { invite }.to have_enqueued_job.on_queue(Rails.application.config.action_mailer.deliver_later_queue_name)
      end
    end

    context 'message contains malicious link' do
      let(:invite) { create(:invite, user: create(:user), message: "Coucou\n<a href=\"https://malicious.site\">trusted anchor</a>") }
      it 'sanitize message' do
        expect(subject.body.decoded).to match(%r{<p>Coucou\s+<br />trusted anchor</p>})
      end
    end
  end
end
