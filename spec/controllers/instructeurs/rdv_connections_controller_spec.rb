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
      expect(response.body).to have_text("Votre compte Démarches Simplifiées avec l’adresse électronique\n      francis.factice.ds@test.gouv.fr")
      expect(response.body).to have_text("est connecté au compte RDV\n      Service Public avec l’adresse électronique francis.factice.rdv@test.gouv.fr.")
    end
  end

  describe "#destroy" do
    before { delete :destroy }

    it do
      expect { rdv_connection.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(flash.alert).to be_nil
      expect(flash.notice).to eq("Votre compte Démarches Simplifiées n’est plus connecté à RDV Service Public.")
      expect(response).to redirect_to(profil_path)
    end
  end
end
