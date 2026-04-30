# frozen_string_literal: true

describe ContactController, question_type: :controller do
  render_views

  context 'signed in' do
    before do
      sign_in user
    end

    let(:user) { create(:user, :with_email_verified) }

    it 'should not have email field' do
      get :index

      expect(response.status).to eq(200)
      expect(response.body).not_to have_content("Votre adresse électronique")
    end

    describe "with dossier" do
      let(:user) { dossier.user }
      let(:dossier) { create(:dossier) }

      it 'should fill dossier_id' do
        get :index, params: { dossier_id: dossier.id }

        expect(response.status).to eq(200)
        expect(response.body).to include((dossier.id).to_s)
      end

      context 'with origin=autosave' do
        it 'prefills the form with autosave error context' do
          get :index, params: { dossier_id: dossier.id, origin: 'autosave', error_id: 'abc123def' }

          expect(response.status).to eq(200)
          expect(assigns(:form).question_type).to eq(ContactForm::TYPE_AUTRE)
          expect(assigns(:form).subject).to eq(I18n.t('contact.prefill.autosave.subject'))
          expect(assigns(:form).text).to match(%r{automatique.+abc123def})
        end
      end

      context 'with unknown origin' do
        it 'does not prefill subject or text' do
          get :index, params: { dossier_id: dossier.id, origin: 'unknown' }

          expect(assigns(:form).subject).to be_nil
          expect(assigns(:form).text).to be_nil
        end
      end

      context 'without origin' do
        it 'does not prefill subject or text' do
          get :index, params: { dossier_id: dossier.id }

          expect(assigns(:form).subject).to be_nil
          expect(assigns(:form).text).to be_nil
        end
      end
    end

    describe "send form" do
      subject do
        post :create, params: { contact_form: params }
      end

      context "when invisible captcha is ignored" do
        let(:params) { { subject: 'bonjour', text: 'un message', question_type: 'procedure_info' } }

        it 'creates a conversation on Crisp' do
          expect { subject }.to \
            change(Commentaire, :count).by(0).and \
            change(ContactForm, :count).by(1)

          contact_form = ContactForm.last
          expect(CrispCreateConversationJob).to have_been_enqueued.with(contact_form)

          expect(contact_form.subject).to eq("bonjour")
          expect(contact_form.text).to eq("un message")
          expect(contact_form.tags).to include("procedure_info")
          expect(contact_form.user_agent).to be_present

          expect(flash[:notice]).to match('Votre message a été envoyé.')
          expect(response).to redirect_to root_path
        end

        context 'when an attacker tries to spoof email via form manipulation' do
          let(:params) { { subject: 'bonjour', text: 'un message', question_type: 'procedure_info', email: 'victim@attacker.com' } }

          it 'ignores the submitted email and uses the signed-in user email' do
            expect { subject }.to change(ContactForm, :count).by(1)

            contact_form = ContactForm.last
            expect(contact_form.email).to be_nil # Email param is ignored
            expect(contact_form.user).to eq(user) # User is set, so CrispJob will use user.email
          end
        end

        context 'when a drafted dossier is mentionned' do
          let(:dossier) { create(:dossier) }
          let(:user) { dossier.user }

          let(:params) do
            {
              dossier_id: dossier.id,
              question_type: ContactForm::TYPE_INSTRUCTION,
              subject: 'bonjour',
              text: 'un message',
            }
          end

          it 'creates a conversation on Crisp' do
            expect { subject }.to \
              change(Commentaire, :count).by(0).and \
              change(ContactForm, :count).by(1)

            contact_form = ContactForm.last
            expect(CrispCreateConversationJob).to have_been_enqueued.with(contact_form)
            expect(contact_form.dossier_id).to eq(dossier.id)

            expect(flash[:notice]).to match('Votre message a été envoyé.')
            expect(response).to redirect_to root_path
          end
        end

        context 'when a submitted dossier is mentionned' do
          let(:dossier) { create(:dossier, :en_construction) }
          let(:user) { dossier.user }

          let(:params) do
            {
              dossier_id: dossier.id,
              question_type: ContactForm::TYPE_INSTRUCTION,
              subject: 'bonjour',
              text: 'un message',
            }
          end

          it 'posts the message to the dossier messagerie' do
            expect { subject }.to change(Commentaire, :count).by(1)
            assert_no_enqueued_jobs(only: CrispCreateConversationJob)

            expect(Commentaire.last.email).to eq(user.email)
            expect(Commentaire.last.dossier).to eq(dossier)
            expect(Commentaire.last.body).to include('[bonjour]')
            expect(Commentaire.last.body).to include('un message')

            expect(flash[:notice]).to match('Votre message a été envoyé sur la messagerie de votre dossier.')
            expect(response).to redirect_to messagerie_dossier_path(dossier)
          end
        end
      end

      context "when invisible captcha is filled" do
        subject do
          post :create, params: {
            contact_form: { subject: 'bonjour', text: 'un message', question_type: 'procedure_info' },
            InvisibleCaptcha.honeypots.sample => 'boom',
          }
        end

        it 'does not create a conversation on Crisp' do
          expect { subject }.not_to change(Commentaire, :count)
          expect(flash[:alert]).to eq(I18n.t('invisible_captcha.sentence_for_humans'))
        end
      end
    end
  end

  context 'signed out' do
    describe "with dossier" do
      it 'should have email field' do
        get :index

        expect(response.status).to eq(200)
        expect(response.body).to have_text("Votre adresse électronique")
      end
    end

    describe 'send form' do
      subject do
        post :create, params: { contact_form: params }
      end

      let(:params) { { subject: 'bonjour', email: "me@rspec.net", text: 'un message', question_type: 'procedure_info' } }

      it 'creates a conversation on Crisp' do
        expect { subject }.to \
          change(Commentaire, :count).by(0).and \
        change(ContactForm, :count).by(1)

        contact_form = ContactForm.last
        expect(CrispCreateConversationJob).to have_been_enqueued.with(contact_form)
        expect(contact_form.email).to eq("me@rspec.net")

        expect(flash[:notice]).to match('Votre message a été envoyé.')
        expect(response).to redirect_to root_path
      end

      context "when email is invalid" do
        let(:params) { super().merge(email: "me@rspec") }

        it 'creates a conversation on Crisp' do
          expect { subject }.not_to have_enqueued_job(CrispCreateConversationJob)
          expect(response.body).to include("Le champ « Votre adresse électronique » est invalide")
          expect(response.body).to include("bonjour")
          expect(response.body).to include("un message")
        end
      end

      context "with an invalid attachment type" do
        let(:params) { super().merge(piece_jointe: "not_a_file") }

        it "returns unprocessable entity status" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("La pièce jointe doit être un fichier")
        end
      end
    end
  end

  context 'contact admin' do
    context 'index' do
      it 'should have professionnal email field' do
        get :admin
        expect(response.body).to have_text('Votre adresse électronique professionnelle')
        expect(response.body).to have_text('téléphone')
        expect(response.body).to include('for_admin')
      end
    end

    context 'create' do
      subject do
        post :create, params: { contact_form: params }
      end

      let(:params) { { for_admin: "true", email: "email@pro.fr", subject: 'bonjour', text: 'un message', question_type: ContactForm::ADMIN_TYPE_QUESTION, phone: '06' } }

      describe "when form is filled" do
        it "creates a conversation on Crisp" do
          expect { subject }.to change(ContactForm, :count).by(1)

          contact_form = ContactForm.last
          expect(CrispCreateConversationJob).to have_been_enqueued.with(contact_form)
          expect(contact_form.email).to eq(params[:email])
          expect(contact_form.phone).to eq("06")
          expect(contact_form.tags).to match_array([ContactForm::ADMIN_TYPE_QUESTION, "contact form"])

          expect(flash[:notice]).to match('Votre message a été envoyé.')
        end

        context "with a piece justificative" do
          let(:logo) { fixture_file_upload('spec/fixtures/files/white.png', 'image/png') }
          let(:params) { super().merge(piece_jointe: logo) }

          it "create blob and pass it to conversation job" do
            expect { subject }.to change(ContactForm, :count).by(1)

            contact_form = ContactForm.last
            expect(contact_form.piece_jointe).to be_attached
          end
        end
      end

      describe "when invisible captcha is filled" do
        subject do
          post :create, params: { contact_form: params, InvisibleCaptcha.honeypots.sample => 'boom' }
        end

        it 'does not create a conversation on Crisp' do
          subject
          expect(flash[:alert]).to eq(I18n.t('invisible_captcha.sentence_for_humans'))
        end
      end
    end
  end
end
