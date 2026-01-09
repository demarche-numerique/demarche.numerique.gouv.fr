# frozen_string_literal: true

describe InvitesController, type: :controller do
  let(:dossier) { create(:dossier, :en_construction) }
  let(:email) { 'plop@octo.com' }
  let(:expert) { create(:expert) }
  let(:procedure) { create(:procedure) }
  let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure) }

  describe '#POST create' do
    let(:invite) { Invite.last }

    before do
      sign_in signed_in_profile
    end

    subject { post :create, params: { dossier_id: dossier.id, invite_email: email }, format: :turbo_stream }

    context "when instructeur is signed_in" do
      let(:signed_in_profile) { create(:instructeur).user }

      shared_examples_for "he can not create invitation" do
        it { expect { subject rescue nil }.to change(Invite, :count).by(0) }
      end

      context 'when instructeur has no access to dossier' do
        it_behaves_like "he can not create invitation"
      end

      context 'when instructeur is invited for avis on dossier' do
        before { create(:avis, experts_procedure: experts_procedure, claimant: create(:instructeur), dossier: dossier) }

        it_behaves_like "he can not create invitation"
      end

      context 'when instructeur has access to dossier' do
        before do
          signed_in_profile.instructeur.groupe_instructeurs << dossier.procedure.defaut_groupe_instructeur
        end

        it_behaves_like "he can not create invitation"

        context 'when is a user who is loged' do
          let(:user) { create(:user) }
          before do
            dossier.update(user: user)
            sign_in(user)
          end

          it { expect { subject }.to change(Invite, :count).by(1) }
        end
      end
    end

    context "when user is signed_in" do
      let(:signed_in_profile) { create(:user) }

      shared_examples_for "he can not create a invite" do
        it do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          expect { subject rescue nil }.to change(Invite, :count).by(0)
        end
      end

      context 'when user has no access to dossier' do
        it_behaves_like "he can not create a invite"
      end

      context 'when user is invited on dossier' do
        before { Invite.create(user: signed_in_profile, email: signed_in_profile.email, dossier: dossier) }

        it_behaves_like "he can not create a invite"
      end

      context 'when user has access to dossier' do
        render_views

        before do
          request.env["HTTP_REFERER"] = "/dossiers/#{dossier.id}/brouillon"
          dossier.update(user: signed_in_profile)
        end

        it { expect { subject }.to change(Invite, :count).by(1) }

        it "update the modal" do
          expect(subject.body).to include("a été envoyée à plop@octo.com")
          expect(subject.body).to match(/Voir les personnes invitées\s+<span[^>]+>1/)
          expect(subject.body).to include("modal.conceal()")
        end

        context 'when email is assign to an user' do
          let! (:user_invite) { create(:user, email: email) }

          before do
            subject
          end

          describe 'Invite information' do
            let(:email) { 'PLIP@octo.com' }
            let(:invite) { Invite.last }

            it 'email is on lower case' do
              expect(invite.email).to eq 'plip@octo.com'
            end
          end

          it "updates the modal" do
            expect(invite.user).to eq user_invite
            expect(subject.body).to include("Une invitation a été envoyée à #{email}")
          end
        end

        context 'when email is not assign to an user' do
          before do
            subject
          end

          it "update the modal" do
            expect(invite.user).to be_nil
            expect(subject.body).to include("Une invitation a été envoyée à #{email}")
          end
        end

        describe 'not an email' do
          context 'when email is not valid' do
            let(:email) { 'plip.com' }

            before do
              subject
            end

            it "renders an error" do
              expect { subject }.not_to change(Invite, :count)
              expect(subject.body).to include("est invalide")
            end
          end

          context "when user does'nt give any email" do
            subject { post :create, params: { dossier_id: dossier.id }, format: :turbo_stream }
            before do
              subject
            end

            it "renders an error" do
              expect { subject }.not_to change(Invite, :count)
              expect(subject.body).to include("doit être rempli")
            end
          end

          context 'when email is already used' do
            let!(:invite) { create(:invite, dossier: dossier) }

            before do
              subject
            end

            it "handle it gracefully" do
              expect { subject }.not_to change(Invite, :count)
              expect(subject.body).to include("Invitation déjà envoyée")
            end
          end
        end

        describe 'send invitation email' do
          context 'when user does not exist' do
            it 'send email' do
              expect(InviteMailer).to receive(:invite_guest).and_return(InviteMailer)
              expect(InviteMailer).to receive(:deliver_later)

              subject
            end
          end

          context 'when user exist' do
            before do
              create :user, email: email
            end

            it 'send email' do
              expect(InviteMailer).to receive(:invite_user).and_return(InviteMailer)
              expect(InviteMailer).to receive(:deliver_later)

              subject
            end
          end
        end
      end
    end
  end

  describe '#GET show' do
    let(:user) { create :user }

    context "when invite without email exists" do
      let(:invite) { create(:invite, dossier: dossier) }

      subject { get :show, params: { id: invite.id, email: email } }

      context 'when email is not set' do
        let(:email) { nil }

        context 'and user is not connected' do
          it 'redirects to the sign-in page' do
            expect(subject).to redirect_to new_user_session_path
            expect(controller.stored_location_for(:user)).to be_present
          end
        end

        context 'and user is connected' do
          let(:invite) { create :invite, dossier: dossier, user: user }

          before { sign_in user }

          it { is_expected.to redirect_to(dossier_path(dossier)) }
        end
      end

      context 'when email is blank' do
        let(:email) { '' }

        it 'redirects to the sign-in page' do
          expect(subject).to redirect_to new_user_session_path
          expect(controller.stored_location_for(:user)).to be_present
        end
      end

      context 'when email is not blank' do
        context 'when email is affected at an user' do
          let(:email) { user.email }

          it 'redirects to the sign-in page' do
            expect(subject).to redirect_to new_user_session_path
            expect(controller.stored_location_for(:user)).to be_present
          end
        end

        context 'when email is not affected at an user' do
          let(:email) { 'new_user@octo.com' }

          it 'redirects to the sign-up page' do
            expect(subject).to redirect_to new_user_registration_path(user: { email: email })
            expect(controller.stored_location_for(:user)).to be_present
          end
        end
      end
    end

    context "when invite with email exists" do
      let(:invite) { create :invite, email: email, dossier: dossier }

      before do
        sign_in user
      end

      subject! { get :show, params: { id: invite.id } }

      it 'clears the stored return location' do
        expect(controller.stored_location_for(:user)).to be nil
      end

      context 'when invitation ID is attached at the user email account' do
        let(:email) { user.email }

        context 'and dossier is a brouillon' do
          let(:dossier) { create :dossier, state: Dossier.states.fetch(:brouillon) }
          it { is_expected.to redirect_to brouillon_dossier_path(dossier) }
        end

        context 'and dossier is not a brouillon' do
          let(:dossier) { create :dossier, :en_construction }
          it { is_expected.to redirect_to(dossier_path(dossier)) }
        end
      end

      context 'when invitation ID is not attached at the user email account' do
        let(:email) { 'fake@email.com' }

        it do
          is_expected.to redirect_to dossiers_path
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe '#DELETE destroy' do
    render_views
    let(:invite) { create(:invite, email: email, dossier: dossier) }

    before do
      invite
      sign_in dossier.user
    end

    subject { delete :destroy, params: { id: invite.id }, format: :turbo_stream }

    context 'when user is signed in' do
      it "destroy invites" do
        expect { subject }.to change { Invite.count }.from(1).to(0)
        expect(response.body).to include("dossier-invites-button-wrapper")
        expect(response.body).to include("L’autorisation de plop@octo.com vient d’être révoquée")
      end
    end

    context 'when dossier does not belong to user' do
      let(:another_user) { create(:user) }

      it 'does not destroy invite' do
        sign_in another_user
        expect { subject }.not_to change { Invite.count }
        expect(response.body).not_to include(".invite-user-action")
      end
    end
  end
end
