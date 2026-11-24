# frozen_string_literal: true

describe Administrateurs::APITokenTransfersController, type: :controller do
  let(:owner) { administrateurs.default }
  let(:recipient) { administrateurs.blank }
  let(:shared) { procedures.individual }
  let(:api_token) { APIToken.generate(owner, allowed_procedure_ids: [shared.id]).first }

  before { shared.administrateurs << recipient }

  context 'as the owner' do
    before { sign_in(owner.user) }

    describe 'new' do
      render_views

      let(:partials) { create_list(:administrateur, 5) }
      let(:details) { response.parsed_body.at_css('details') }

      before do
        api_token.update!(allowed_procedure_ids: [shared.id, procedures.brouillon.id])
        procedures.brouillon.administrateurs << recipient
        partials.first(4).each { shared.administrateurs << it }
      end

      it 'offers the token to the co-administrateurs covering it, and tells what the others miss' do
        get :new, params: { api_token_id: api_token.id }

        expect(response.parsed_body.css('input[name="recipient_id"]').map { it['value'] }).to eq([recipient.id.to_s])
        expect(details['open']).not_to be_nil
        expect(details.text).to include("#{partials.first.email} : il manque 1 démarche")
      end

      it 'folds the others away from five' do
        shared.administrateurs << partials.last
        get :new, params: { api_token_id: api_token.id }

        expect(details['open']).to be_nil
      end
    end

    describe 'create' do
      render_views

      it 'offers the token' do
        post :create, params: { api_token_id: api_token.id, recipient_id: recipient.id }
        expect(api_token.reload.transfer_recipient).to eq(recipient)
        expect(response).to redirect_to(edit_admin_api_token_path(api_token))
      end

      it 'refuses an administrateur who does not cover the token, and says so under the choice' do
        post :create, params: { api_token_id: api_token.id, recipient_id: create(:administrateur).id }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css('fieldset .fr-message--error').text).to eq('Choisissez un administrateur qui administre toutes les démarches du jeton.')
        expect(api_token.reload.transfer_recipient).to be_nil
      end
    end

    context 'when the token can no longer be handed over' do
      before { api_token.update_column(:expires_at, 1.day.ago.to_date) }

      it 'sends back to the token, from the choice as from its sending' do
        get :new, params: { api_token_id: api_token.id }
        expect(response).to redirect_to(edit_admin_api_token_path(api_token))
        expect(flash.alert).to eq('Ce jeton ne peut pas être transmis.')

        post :create, params: { api_token_id: api_token.id, recipient_id: recipient.id }
        expect(response).to redirect_to(edit_admin_api_token_path(api_token))
      end
    end

    describe 'destroy' do
      before { api_token.offer_transfer!(recipient, by: owner) }

      it 'cancels the offer' do
        delete :destroy, params: { api_token_id: api_token.id }
        expect(api_token.reload.transfer_recipient).to be_nil
        expect(response).to redirect_to(edit_admin_api_token_path(api_token))
      end
    end
  end

  context 'as a co-administrateur who does not own the token' do
    before { sign_in(recipient.user) }

    it 'cannot offer it' do
      expect { post :create, params: { api_token_id: api_token.id, recipient_id: recipient.id } }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
