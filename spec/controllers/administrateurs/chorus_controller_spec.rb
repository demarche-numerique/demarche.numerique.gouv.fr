# frozen_string_literal: true

describe Administrateurs::ChorusController, type: :controller do
  let(:user) { create(:user) }
  let(:admin) { create(:administrateur, user: create(:user)) }
  let(:procedure) { create(:procedure, administrateurs: [admin]) }

  describe '#edit' do
    subject { get :edit, params: { procedure_id: procedure.id } }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in but not admin of procedure' do
      before { sign_in(user) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed as admin' do
      before { sign_in(admin.user) }
      it { is_expected.to have_http_status(200) }

      context 'rendered' do
        render_views

        it 'renders the budget framework form' do
          expect(subject).to have_http_status(200)
          expect(response.body).to have_selector('h1', text: 'Cadre budgétaire')
          expect(response.body).to have_text('Cas d’usage')
        end
      end
    end
  end

  describe '#update' do
    let(:chorus_configuration_params) { {} }
    subject do
      put :update,
          params: {
            procedure_id: procedure.id,
            chorus_configuration: chorus_configuration_params,
          }
    end

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in but not admin of procedure' do
      before { sign_in(user) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed as admin' do
      before { sign_in(admin.user) }
      let(:domaine_fonctionnel) { nil }
      let(:referentiel_de_programmation) { nil }

      context "partial valid payload" do
        let(:centre_de_cout) { '{"code":"D00C8DX004","label":"Aumôniers+protestant","ville":null,"code_postal":null,"description":"Aumoniers+protestants"}' }
        let(:chorus_configuration_params) do
          {
            centre_de_cout:, domaine_fonctionnel:, referentiel_de_programmation:,
          }
        end
        it 'updates params and redirect back to complete all infos' do
          expect(subject).to redirect_to(edit_admin_procedure_chorus_path(procedure))
          expect(flash[:notice]).to eq("La configuration Chorus a été mise à jour. Veuillez renseigner le reste des informations pour faciliter le rapprochement des données.")

          procedure.reload

          expect(procedure.chorus_configuration.centre_de_cout).to eq(JSON.parse(centre_de_cout))
          expect(procedure.chorus_configuration.domaine_fonctionnel).to eq(nil)
          expect(procedure.chorus_configuration.referentiel_de_programmation).to eq(nil)
        end
      end

      context "full valid payload" do
        let(:centre_de_cout) { '{"code":"D00C8DX004","label":"Aumôniers+protestant","ville":null,"code_postal":null,"description":"Aumoniers+protestants"}' }
        let(:domaine_fonctionnel) { '{"code":"0105-05-01","label":"Formation+des+élites+et+cadres+de+sécurité+et+de+défense","description":null,"code_programme":"105"}' }
        let(:referentiel_de_programmation) { '{"code":"010101010101","label":"DOTATIONS+CARPA+AJ+ET+AUTRES+INTERVENTIONS","description":null,"code_programme":"101"}' }
        let(:chorus_configuration_params) do
          {
            centre_de_cout:, domaine_fonctionnel:, referentiel_de_programmation:,
          }
        end

        it 'updates params and redirects to add champs EngagementJuridique' do
          expect(subject).to redirect_to(add_champ_engagement_juridique_admin_procedure_chorus_path(procedure))
          expect(flash[:notice]).to eq("La configuration Chorus a été mise à jour.")

          procedure.reload

          expect(procedure.chorus_configuration.centre_de_cout).to eq(JSON.parse(centre_de_cout))
          expect(procedure.chorus_configuration.domaine_fonctionnel).to eq(JSON.parse(domaine_fonctionnel))
          expect(procedure.chorus_configuration.referentiel_de_programmation).to eq(JSON.parse(referentiel_de_programmation))
        end
      end
    end
  end

  describe '#add_champ_engagement_juridique' do
    render_views
    subject { get :add_champ_engagement_juridique, params: { procedure_id: procedure.id } }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in but not admin of procedure' do
      before { sign_in(user) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed as admin' do
      before { sign_in(admin.user) }

      it 'have links to add annotation' do
        expect(subject).to have_http_status(:success)
        expect(response.body).to have_link("Ajouter une annotation privée EJ", href: annotations_admin_procedure_path(procedure))
      end
    end
  end
end
