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

  describe "POST create" do
    subject { post :create, params: { dossier_transfer: { email: email, dossier: dossier.id } } }

    before do
      sign_in(sender_user)
      subject
    end

    context "with valid email" do
      let(:email) { "test@rspec.net" }

      it do
        expect(DossierTransfer.last.email).to eq(email)
        expect(DossierTransfer.last.dossiers).to eq([dossier])
      end
    end

    context 'with upper case email' do
      let(:email) { "Test@rspec.net" }
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
