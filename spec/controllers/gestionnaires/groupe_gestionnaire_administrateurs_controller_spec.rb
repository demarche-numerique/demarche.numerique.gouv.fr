# frozen_string_literal: true

describe Gestionnaires::GroupeGestionnaireAdministrateursController, type: :controller do
  let(:gestionnaire) { create(:gestionnaire).tap { _1.user.update(last_sign_in_at: Time.zone.now) } }
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }

  render_views

  before { sign_in gestionnaire.user }

  describe '#index' do
    let(:administrateur) { create(:administrateur) }

    before do
      groupe_gestionnaire.administrateurs << administrateur
      get :index, params: { groupe_gestionnaire_id: groupe_gestionnaire.id }
    end

    it do
      expect(response.body).to have_css("h1", text: groupe_gestionnaire.name)
      expect(response.body).to include(administrateur.email)
      expect(response.body).to have_field('administrateur_email')
    end
  end

  describe '#create' do
    before do
      post :create,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          administrateur: { email: new_administrateur_email },
        },
        format: :turbo_stream
    end

    context 'of a new administrateur' do
      let(:new_administrateur_email) { 'new_administrateur@mail.com' }

      it do
        expect(groupe_gestionnaire.reload.administrateurs.map(&:email)).to include(new_administrateur_email)
        expect(response.body).to include("Les administrateurs ont bien été affectés au groupe gestionnaire")
        expect(response.body).to have_css('turbo-stream[action="replace"][target="new_administrateur"]')
        expect(response.body).to include(new_administrateur_email)
      end
    end
  end

  describe '#destroy' do
    let(:gestionnaire) { create(:gestionnaire) }
    let(:new_administrateur) { create(:administrateur) }

    before do
      groupe_gestionnaire.administrateurs << new_administrateur
    end

    def destroy(administrateur)
      delete :destroy,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          id: administrateur.id,
        },
        format: :turbo_stream
    end

    context 'when administrateur is in the groupe_gestionnaire' do
      before { destroy(new_administrateur) }

      it do
        expect(groupe_gestionnaire.reload.administrateurs.count).to eq(0)
        expect(response.body).to include("L’administrateur «&nbsp;#{new_administrateur.email}&nbsp;» a été supprimé.")
      end
    end

    context 'when administrateur has some procedure' do
      let(:administrateur_with_procedure) { administrateurs.default }
      let!(:procedure) { create(:procedure_with_dossiers, administrateur: administrateur_with_procedure) }
      before do
        groupe_gestionnaire.administrateurs << administrateur_with_procedure
        destroy(administrateur_with_procedure)
      end

      it do
        expect(groupe_gestionnaire.reload.administrateurs.count).to eq(2)
        expect(response.body).to include("L’administrateur «&nbsp;#{administrateur_with_procedure.email}&nbsp;» ne peut pas être supprimé du groupe gestionnaire.")
      end
    end

    context 'when administrateur is not in the groupe_gestionnaire' do
      let(:other_administrateur) { administrateurs.default }

      it 'does not disclose the unrelated administrateur email' do
        expect { destroy(other_administrateur) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(groupe_gestionnaire.reload.administrateurs.count).to eq(1)
        expect(flash.alert.to_s).not_to include(other_administrateur.email)
      end
    end
  end

  describe '#remove' do
    let(:gestionnaire) { create(:gestionnaire) }
    let(:new_administrateur) { create(:administrateur) }

    before do
      groupe_gestionnaire.administrateurs << new_administrateur
    end

    def remove(administrateur)
      delete :remove,
        params: {
          groupe_gestionnaire_id: groupe_gestionnaire.id,
          id: administrateur.id,
        },
        format: :turbo_stream
    end

    context 'when administrateur is in the groupe_gestionnaire' do
      before { remove(new_administrateur) }

      it do
        expect(groupe_gestionnaire.reload.administrateurs.count).to eq(0)
        expect(response.body).to include("L’administrateur «&nbsp;#{new_administrateur.email}&nbsp;» a été retiré du groupe gestionnaire.")
      end
    end

    context 'when administrateur is not in the groupe_gestionnaire' do
      let(:other_administrateur) { create(:administrateur) }

      it 'does not disclose the unrelated administrateur email' do
        expect { remove(other_administrateur) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(groupe_gestionnaire.reload.administrateurs.count).to eq(1)
        expect(flash.alert.to_s).not_to include(other_administrateur.email)
      end
    end
  end
end
