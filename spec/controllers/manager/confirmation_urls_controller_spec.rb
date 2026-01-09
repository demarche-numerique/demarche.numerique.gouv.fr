# frozen_string_literal: true

describe Manager::ConfirmationUrlsController, type: :controller do
  let(:inviter_super_admin) { create(:super_admin) }
  let(:inviter_administrateur) { create(:administrateur, email: inviter_super_admin.email) }

  let(:invited_super_admin) { create(:super_admin) }
  let(:invited_administrateur) { create(:administrateur, email: invited_super_admin.email) }

  let(:procedure) { create(:procedure, administrateurs: [inviter_administrateur]) }

  before { sign_in inviter_super_admin }

  describe "#add_administrateur_with_confirmation" do
    render_views

    let(:params) do
      {
        procedure_id: procedure.id,
        email: invited_administrateur.email,
      }
    end

    before { get :new, params: params }

    it "shows the confirmation url with encrypted parameters" do
      expect(response).to render_template(:new)

      expect(response.body).to match(/Veuillez partager ce lien/)

      path_base = new_manager_procedure_administrateur_confirmation_path(procedure)
      expect(response.body).to match(
        %r{#{Regexp.escape(path_base)}\?q=\S{30,}}m
      )
    end

    describe 'edge cases' do
      context 'when the administrateur does not exist' do
        let(:params) do
          {
            procedure_id: procedure.id,
            email: "wrong@email.com",
          }
        end

        it do
          expect(flash[:alert]).to match(/Cet administrateur n’existe pas/)
          expect(response).to redirect_to(manager_procedure_path(procedure))
        end
      end

      context 'when the administrateur has already been added to the procedure' do
        let(:params) do
          {
            procedure_id: procedure.id,
            email: inviter_super_admin.email,
          }
        end

        it do
          expect(flash[:alert]).to match(/Cet administrateur a déjà été ajouté/)
          expect(response).to redirect_to(manager_procedure_path(procedure))
        end
      end
    end
  end
end
