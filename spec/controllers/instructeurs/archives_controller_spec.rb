# frozen_string_literal: true

describe Instructeurs::ArchivesController, type: :controller do
  let(:procedure1) { create(:procedure, :published, groupe_instructeurs: [assign_to.groupe_instructeur]) }
  let(:procedure2) { create(:procedure, :published, groupe_instructeurs: [gi2]) }
  let!(:instructeur) { create(:instructeur, groupe_instructeurs: [gi2]) }
  let!(:archive1) { create(:archive, :generated, groupe_instructeurs: [assign_to.groupe_instructeur], user_profile: instructeur) }
  let!(:archive2) { create(:archive, :generated, groupe_instructeurs: [gi2]) }
  let!(:assign_to) { create(:assign_to, instructeur: instructeur, groupe_instructeur: build(:groupe_instructeur), manager: manager) }
  let(:gi2) { create(:groupe_instructeur) }

  before do
    sign_in(instructeur.user)
  end

  describe '#index' do
    before do
      create_dossier_for_month(procedure1, 2021, 3)
      create_dossier_for_month(procedure1, 2021, 3)
      create_dossier_for_month(procedure1, 2021, 2)
      travel_to(Time.zone.local(2021, 3, 5))
    end
    subject { get :index, params: { procedure_id: procedure1.id } }

    context 'signed in not as manager' do
      let(:manager) { false }

      it { is_expected.to have_http_status(:success) }

      context 'with views' do
        render_views

        it 'titles the page with a h2 under the procedure h1' do
          subject
          expect(response.body).to have_selector('main h1', count: 1)
          expect(response.body).to have_selector('main h2.fr-h4', text: 'Téléchargement mensuel')
        end
      end

      it 'assigns archives' do
        subject
        expect(assigns(:archives)).to eq([archive1])
      end

      context "IDOR: archive créée par un autre instructeur du même groupe" do
        let(:other_instructeur) { create(:instructeur, groupe_instructeurs: [assign_to.groupe_instructeur]) }
        let!(:archive_from_other) { create(:archive, :generated, groupe_instructeurs: [assign_to.groupe_instructeur], user_profile: other_instructeur) }

        it "n'expose pas l'archive de l'autre instructeur" do
          subject
          expect(assigns(:archives)).not_to include(archive_from_other)
        end
      end
    end

    context 'signed in as manager' do
      let(:manager) { true }

      before do
        sign_in(instructeur.user)
      end

      it { is_expected.to have_http_status(:forbidden) }
    end
  end

  describe '#create' do
    let(:subject) do
      post :create, params: { procedure_id: procedure1.id, type: 'monthly', month: month }
    end

    let(:month) { '21-03' }
    let(:date_month) { Date.strptime(month, "%Y-%m") }

    context 'signed in not as manager' do
      let(:manager) { false }

      it "performs archive creation job" do
        expect { subject }.to have_enqueued_job(ArchiveCreationJob).with(procedure1, an_instance_of(Archive), instructeur)
        expect(flash.notice).to include("Votre demande a été prise en compte")
      end
    end

    context 'signed in as manager' do
      let(:manager) { true }

      it { is_expected.to have_http_status(:forbidden) }
    end
  end

  private

  def create_dossier_for_month(procedure, year, month)
    travel_to(Time.zone.local(year, month, 5))
    create(:dossier, :accepte, :with_attestation_acceptation, procedure: procedure)
  end
end
