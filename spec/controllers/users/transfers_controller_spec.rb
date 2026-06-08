# frozen_string_literal: true

describe Users::TransfersController, type: :controller do
  let(:sender_user) { create(:user) }
  let(:recipient_user) { create(:user) }
  let(:dossier) { create(:dossier, user: sender_user) }

  describe 'DELETE destroy' do
    context "as transfer receiver" do
      let(:dossier_transfert) { DossierTransfer.initiate(recipient_user.email, [dossier]) }

      subject { delete :destroy, params: { id: dossier_transfert.id } }

      before do
        sign_in(recipient_user)
      end

      it { expect { subject }.not_to raise_error }

      it "deletes dossier transfert" do
        subject
        expect { dossier_transfert.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { (flash.notice).to eq('La demande de transfert a été supprimée avec succès') }
        expect { (subject).to redirect_to dossiers_path }
      end
    end

    context "as transfer sender" do
      let(:dossier_transfert) { DossierTransfer.initiate(recipient_user.email, [dossier]) }

      subject { delete :destroy, params: { id: dossier_transfert.id } }

      before do
        sign_in(sender_user)
      end

      it { expect { subject }.not_to raise_error }

      it "deletes dossier transfert" do
        subject
        expect { dossier_transfert.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "as transfer unauthorized" do
      let(:dossier_transfert) { DossierTransfer.initiate(recipient_user.email, [dossier]) }
      let(:random_user) { create(:user) }

      subject { delete :destroy, params: { id: dossier_transfert.id } }

      before do
        sign_in(random_user)
      end

      it { expect { subject }.not_to raise_error }

      it "does not delete dossier transfert" do
        subject

        expect { dossier_transfert.reload.to eq(dossier_transfert) }
        expect { (flash.alert).to eq("Vous n’avez pas l’autorisation pour supprimer cette demande de transfert") }
        expect { (subject).to redirect_to dossiers_path }
      end
    end
  end

  describe 'PATCH #update' do
    before { sign_in(recipient_user) }

    context 'when accept succeeds' do
      let(:dossier_transfert) { DossierTransfer.initiate(recipient_user.email, [dossier]) }

      it 'sets a notice flash' do
        patch :update, params: { id: dossier_transfert.id }
        expect(flash.notice).to be_present
      end
    end

    context 'when the transfer is unknown or not addressed to the user' do
      it 'sets the unauthorized alert' do
        patch :update, params: { id: 99999 }
        expect(flash.alert).to eq(I18n.t('users.dossiers.transferer.unauthorized'))
      end
    end

    context 'when the transfer no longer has any dossier' do
      let(:dossier_transfert) { DossierTransfer.initiate(recipient_user.email, [dossier]) }

      before { dossier_transfert.dossiers.update_all(dossier_transfer_id: nil) }

      it 'sets the nothing_to_transfer alert and does not claim success' do
        patch :update, params: { id: dossier_transfert.id }
        expect(flash.alert).to eq(I18n.t('users.dossiers.transferer.nothing_to_transfer'))
        expect(flash.notice).to be_nil
      end
    end
  end

  describe "POST create" do
    before do
      sign_in(sender_user)
    end

    subject { post :create, params: { id: dossier.id, dossier_transfer: { email: email } } }

    context "transfers only the targeted dossier, not all" do
      let(:email) { "test@rspec.net" }
      let!(:other_dossier) { create(:dossier, user: sender_user) }

      it "transfers only the dossier from the URL" do
        expect { subject }.to change { DossierTransfer.count }.by(1)
        expect(DossierTransfer.last.dossiers).to eq([dossier])
      end
    end

    context "with valid email" do
      let(:email) { "test@rspec.net" }

      before { subject }

      it do
        expect(DossierTransfer.last.email).to eq(email)
        expect(DossierTransfer.last.dossiers).to eq([dossier])
      end
    end

    context 'with upper case email' do
      let(:email) { "Test@rspec.net" }
      before { subject }
      it { expect(DossierTransfer.last.email).to eq(email.strip.downcase) }
    end

    shared_examples 'email error' do
      it do
        expect { subject }.not_to change { DossierTransfer.count }
        expect(flash.alert).to include(expected_error)
        is_expected.to redirect_to transferer_dossier_path(dossier.id)
      end
    end

    context "when email is empty" do
      let(:email) { "" }
      it_behaves_like 'email error' do
        let(:expected_error) { 'L’adresse électronique doit être rempli' }
      end
    end

    context "when email is invalid" do
      let(:email) { "not-an-email" }
      it_behaves_like 'email error' do
        let(:expected_error) { "L’adresse électronique est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com" }
      end
    end
  end
end
