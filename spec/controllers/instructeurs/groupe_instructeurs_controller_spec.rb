# frozen_string_literal: true

describe Instructeurs::GroupeInstructeursController, type: :controller do
  render_views
  let(:administrateur) { create(:administrateur) }
  let(:instructeur) { administrateur.instructeur }
  let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }
  let!(:gi_1_1) { procedure.defaut_groupe_instructeur }
  let!(:gi_1_2) { create(:groupe_instructeur, label: 'groupe instructeur 2', procedure: procedure) }

  let(:procedure2) { create(:procedure, :published) }
  let!(:gi_2_2) { create(:groupe_instructeur, label: 'groupe instructeur 2 2', procedure: procedure2) }

  before do
    gi_1_2.instructeurs << instructeur
    sign_in(instructeur.user)
  end

  describe "before_action: ensure_allowed!" do
    it "is present" do
      before_actions = Instructeurs::GroupeInstructeursController
        ._process_action_callbacks
        .filter { |process_action_callbacks| process_action_callbacks.kind == :before }
        .map(&:filter)

      expect(before_actions).to include(:ensure_allowed!)
    end
  end

  describe '#index (plus, ensure_allowed!)' do
    context 'when i own the procedure' do
      before { get :index, params: { procedure_id: procedure.id } }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'when i am an instructeur of the procedure and instructeurs_self_management_enabled is true' do
      let(:procedure) { create(:procedure, :published, instructeurs_self_management_enabled: true) }
      before { get :index, params: { procedure_id: procedure.id } }

      it 'when a procedure has multiple groups' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(gi_1_2.label)
        expect(response.body).not_to include(gi_1_1.label)
        expect(response.body).not_to include(gi_2_2.label)
      end
    end

    context 'when i am an instructor of the procedure, and instructeurs_self_management_enabled is false' do
      let(:procedure) { create(:procedure, :published, :new_administrateur, instructeurs_self_management_enabled: false) }
      before { get :index, params: { procedure_id: procedure.id } }

      it "works" do
        expect(response).to have_http_status(:redirect)
        expect(flash.alert).to eq("Vous n’avez pas le droit de gérer les instructeurs de cette démarche")
      end
    end

    context 'i am an instructor, not on the procedure' do
      let(:procedure) { create(:procedure, :published, :new_administrateur, instructeurs_self_management_enabled: true) }
      before do
        sign_in(create(:instructeur).user)
        get :index, params: { procedure_id: procedure.id }
      end

      it "works" do
        expect(response).to have_http_status(:redirect)
        expect(flash.alert).to eq("Vous n’avez pas accès à cette démarche")
      end
    end
  end

  describe '#show' do
    context 'as an instructeur of a group, with self management enabled' do
      render_views

      let(:instructeur) { create(:instructeur) }

      before do
        procedure.update(instructeurs_self_management_enabled: true)
        get :show, params: { procedure_id: procedure.id, id: gi_1_2.id }
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe '#add_instructeurs' do
    before do
      allow(GroupeInstructeurMailer).to receive(:confirm_and_notify_added_instructeur).and_call_original
      allow(GroupeInstructeurMailer).to receive(:notify_added_instructeurs).and_call_original
    end

    subject do
      post :add_instructeurs,
        params: {
          procedure_id: procedure.id,
          id: gi_1_2.id,
          emails: [new_instructeur_email],
        }
    end

    context 'of a new instructeur' do
      let(:new_instructeur_email) { 'new_instructeur@gmail.com' }
      before { subject }

      it "works" do
        expect(gi_1_2.instructeurs.map(&:email)).to include(new_instructeur_email)
        expect(flash.notice).to be_present
        expect(subject).to redirect_to(instructeur_groupe_path(procedure, gi_1_2))
        expect(GroupeInstructeurMailer).to have_received(:confirm_and_notify_added_instructeur).with(instance_of(Instructeur), gi_1_2, anything)
        expect(GroupeInstructeurMailer).not_to have_received(:notify_added_instructeurs)
      end
    end

    context 'of an instructeur already known and with email verified' do
      let(:known_instructeur) { create(:instructeur, :email_verified) }
      let(:new_instructeur_email) { known_instructeur.email }

      before { subject }

      it "works" do
        expect(gi_1_2.instructeurs.map(&:email)).to include(new_instructeur_email)
        expect(flash.notice).to be_present
        expect(subject).to redirect_to(instructeur_groupe_path(procedure, gi_1_2))
        expect(GroupeInstructeurMailer).not_to have_received(:confirm_and_notify_added_instructeur)
        expect(GroupeInstructeurMailer).to have_received(:notify_added_instructeurs)
      end
    end

    context 'of an instructeur already known that has received a invitation email long time ago' do
      let(:known_instructeur) { create(:instructeur, user: create(:user, { reset_password_sent_at: 10.days.ago })) }
      let(:new_instructeur_email) { known_instructeur.email }

      before { subject }

      it "works" do
        expect(gi_1_2.instructeurs.map(&:email)).to include(new_instructeur_email)
        expect(flash.notice).to be_present
        expect(subject).to redirect_to(instructeur_groupe_path(procedure, gi_1_2))
        expect(GroupeInstructeurMailer).to have_received(:confirm_and_notify_added_instructeur)
        expect(GroupeInstructeurMailer).not_to have_received(:notify_added_instructeurs)
      end
    end

    context 'of an instructeur already in the group' do
      let(:new_instructeur_email) { instructeur.email }
      before do
        instructeur.user.update(email_verified_at: 1.day.ago)
        subject
      end

      it "works" do
        expect(subject).to redirect_to(instructeur_groupe_path(procedure, gi_1_2))
        expect(GroupeInstructeurMailer).not_to have_received(:confirm_and_notify_added_instructeur)
        expect(GroupeInstructeurMailer).not_to have_received(:notify_added_instructeurs)
      end
    end

    context 'invalid email' do
      let(:new_instructeur_email) { 'invalid' }

      it "works" do
        expect { subject }.not_to enqueue_email
        expect(flash.alert).to include(new_instructeur_email)
        expect(GroupeInstructeurMailer).not_to have_received(:confirm_and_notify_added_instructeur)
        expect(GroupeInstructeurMailer).not_to have_received(:notify_added_instructeurs)
      end
    end
  end

  describe '#remove_instructeur' do
    let(:new_instructeur) { create(:instructeur) }
    let(:dossier) { create(:dossier) }

    before do
      gi_1_1.instructeurs << instructeur << new_instructeur
      gi_1_1.dossiers << dossier
      new_instructeur.followed_dossiers << dossier
    end

    def remove_instructeur(instructeur)
      delete :remove_instructeur,
        params: {
          procedure_id: procedure.id,
          id: gi_1_1.id,
          instructeur: { id: instructeur.id },
        }
    end

    context 'when there are many instructeurs' do
      before { remove_instructeur(new_instructeur) }

      it "works" do
        expect(gi_1_1.instructeurs).to include(instructeur)
        expect(gi_1_1.reload.instructeurs.count).to eq(1)
        expect(new_instructeur.reload.follows.count).to eq(0)
        expect(response).to redirect_to(instructeur_groupe_path(procedure, gi_1_1))
      end
    end

    context 'when there is only one instructeur' do
      before do
        remove_instructeur(new_instructeur)
        remove_instructeur(instructeur)
      end

      it "works" do
        expect(gi_1_1.instructeurs).to include(instructeur)
        expect(gi_1_1.instructeurs.count).to eq(1)
        expect(flash.alert).to eq('Suppression impossible : il doit y avoir au moins un instructeur dans le groupe')
        expect(response).to redirect_to(instructeur_groupe_path(procedure, gi_1_1))
      end
    end

    context 'when the instructeur id belongs to an instructeur of another group' do
      let(:other_instructeur) { create(:instructeur, email: 'other-instructeur@example.com') }

      before do
        gi_2_2.instructeurs << other_instructeur
        delete :remove_instructeur,
          params: {
            procedure_id: procedure.id,
            id: gi_1_1.id,
            instructeur: { id: other_instructeur.id },
          }
      end

      it 'does not reference the other instructeur email in flash messages' do
        expect(flash[:notice].to_s).not_to include(other_instructeur.email)
        expect(flash[:alert].to_s).not_to include(other_instructeur.email)
      end

      it 'does not remove the instructeur from their own group' do
        expect(gi_2_2.reload.instructeurs).to include(other_instructeur)
      end
    end
  end

  describe '#add_signature' do
    let(:signature) { fixture_file_upload('spec/fixtures/files/black.png', 'image/png') }

    before do
      post :add_signature,
        params: {
          procedure_id: procedure.id,
          id: gi_1_2.id,
          groupe_instructeur: {
            signature: signature,
          },
        }
    end

    it "works" do
      expect(response).to redirect_to(instructeur_groupe_path(procedure, gi_1_2))
      expect(gi_1_2.reload.signature).to be_attached
    end
  end
end
