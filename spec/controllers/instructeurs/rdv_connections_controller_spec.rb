# frozen_string_literal: true

describe Instructeurs::RdvConnectionsController, type: :controller do
  let(:instructeur) { create(:instructeur, email: "francis.factice.ds@test.gouv.fr") }
  let!(:rdv_connection) { create(:rdv_connection, instructeur: instructeur) }

  before do
    sign_in(instructeur.user)
  end

  describe '#show' do
    subject { get :show }
    render_views

    before do
      expect_any_instance_of(RdvService).to receive(:get_account_info).and_return({ "email" => "francis.factice.rdv@test.gouv.fr" })

      subject
    end

    it "gives information about my connection to RDV Service Public" do
      expect(response.body).to have_text("Votre compte #{APPLICATION_NAME} avec l’adresse électronique francis.factice.ds@test.gouv.fr")
      expect(response.body).to have_text("est connecté au compte RDV Service Public avec l’adresse électronique francis.factice.rdv@test.gouv.fr.")
    end
  end

  describe "#destroy" do
    before { delete :destroy }

    it do
      expect { rdv_connection.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(flash.alert).to be_nil
      expect(flash.notice).to eq("Votre compte #{APPLICATION_NAME} n’est plus connecté à RDV Service Public.")
      expect(response).to redirect_to(profil_path)
    end

    context "with a valid internal redirect_path" do
      before { delete :destroy, params: { redirect_path: "/instructeurs/procedures/1/dossiers/2/rendez_vous" } }

      it { expect(response).to redirect_to("/instructeurs/procedures/1/dossiers/2/rendez_vous") }
    end

    context "with an external redirect_path (open redirect attempt)" do
      before { delete :destroy, params: { redirect_path: "https://evil.example/login" } }

      it { expect(response).to redirect_to(profil_path) }
    end

    context "with a protocol-relative redirect_path (open redirect bypass)" do
      before { delete :destroy, params: { redirect_path: "//evil.example/login" } }

      it { expect(response).to redirect_to(profil_path) }
    end
  end
end
