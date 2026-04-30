# frozen_string_literal: true

describe Manager::SuperAdminsController, type: :controller do
  let!(:signed_in_super_admin) { create(:super_admin) }

  before { sign_in signed_in_super_admin }

  describe '#index' do
    render_views

    let!(:other_super_admin) { create(:super_admin) }

    context 'when the search term is a fragment of another super_admin encrypted_password' do
      let(:hash_fragment) { other_super_admin.encrypted_password[20, 15] }

      subject(:search_request) { get :index, params: { search: hash_fragment } }

      it 'does not match records by their password hash' do
        search_request
        expect(response.body).not_to include(other_super_admin.email)
      end
    end
  end
end
