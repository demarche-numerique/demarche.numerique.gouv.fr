# frozen_string_literal: true

describe Gestionnaires::GroupeGestionnaireGestionnairesController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire).tap { it.user.update(last_sign_in_at: Time.zone.now) } }
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }

  render_views

  before { sign_in gestionnaire.user }

  describe '#index' do
    before { get :index, params: { groupe_gestionnaire_id: groupe_gestionnaire.id } }

    it do
      expect(response.body).to have_css("h1", text: groupe_gestionnaire.name)
      expect(response.body).to have_css('#gestionnaires', text: gestionnaire.email)
      expect(response.body).to have_field('gestionnaire_email')
    end
  end

  describe '#create' do
    before do
      post :create,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          gestionnaire: { email: new_gestionnaire_email },
        },
        format: :turbo_stream
    end

    context 'of a new gestionnaire' do
      let(:new_gestionnaire_email) { 'new_gestionnaire@mail.com' }

      it do
        expect(groupe_gestionnaire.reload.gestionnaires.map(&:email)).to include(new_gestionnaire_email)
        expect(response.body).to include("Les gestionnaires ont bien été affectés au groupe gestionnaire")
        expect(response.body).to have_css('turbo-stream[action="replace"][target="new_gestionnaire"]')
        expect(response.body).to include(new_gestionnaire_email)
      end
    end
  end

  describe '#destroy' do
    let(:gestionnaire) { create(:gestionnaire) }
    let(:new_gestionnaire) { create(:gestionnaire) }

    before do
      groupe_gestionnaire.gestionnaires << gestionnaire << new_gestionnaire
    end

    def remove_gestionnaire(gestionnaire)
      delete :destroy,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          id: gestionnaire.id,
        },
        format: :turbo_stream
    end

    context 'when there are many gestionnaires' do
      before { remove_gestionnaire(new_gestionnaire) }

      it do
        expect(groupe_gestionnaire.gestionnaires).to include(gestionnaire)
        expect(groupe_gestionnaire.reload.gestionnaires.count).to eq(1)
        expect(response.body).to include("Le gestionnaire «&nbsp;#{new_gestionnaire.email}&nbsp;» a été retiré du groupe gestionnaire.")
        expect(response.body).to have_css('turbo-stream[action="focus"][target="gestionnaire_email"]')
      end
    end

    context 'when several gestionnaires remain' do
      before do
        groupe_gestionnaire.gestionnaires << create(:gestionnaire)
        remove_gestionnaire(new_gestionnaire)
      end

      it { expect(response.body).to have_css('turbo-stream[action="focus"][targets="#gestionnaires tr:first-child input[type=\"submit\"]"]') }
    end

    context 'when there is only one gestionnaire' do
      before do
        remove_gestionnaire(new_gestionnaire)
        remove_gestionnaire(gestionnaire)
      end

      it do
        expect(groupe_gestionnaire.gestionnaires).to include(gestionnaire)
        expect(groupe_gestionnaire.gestionnaires.count).to eq(1)
        expect(response.body).to include('Suppression impossible : il doit y avoir au moins un gestionnaire dans le groupe racine')
      end
    end

    context 'when the id belongs to a gestionnaire outside the group' do
      let(:unrelated_gestionnaire) { create(:gestionnaire) }

      subject(:cross_group_request) { remove_gestionnaire(unrelated_gestionnaire) }

      it 'does not disclose the unrelated gestionnaire email' do
        expect { cross_group_request }.to raise_error(ActiveRecord::RecordNotFound)
        expect(flash.alert.to_s).not_to include(unrelated_gestionnaire.email)
      end
    end
  end
end
