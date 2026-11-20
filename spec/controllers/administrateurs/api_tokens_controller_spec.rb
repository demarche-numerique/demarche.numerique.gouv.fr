# frozen_string_literal: true

describe Administrateurs::APITokensController, type: :controller do
  let(:admin) { administrateurs.default }
  let(:procedure) { create(:procedure, administrateur: admin) }

  before { sign_in(admin.user) }

  before { travel_to(Time.zone.local(2020, 1, 1, 12, 0, 0)) }

  # Pin the cap so the suite does not depend on the local configuration.
  before { stub_const('APIToken::MAX_LIFETIME', 365.days) }

  describe 'create' do
    let(:default_params) do
      {
        name: 'Test',
        access: 'read_write',
        target: 'all',
        lifetime: 'oneWeek',
      }
    end
    let(:token) { APIToken.last }

    subject { post :create, params: }

    before { subject }

    context 'with write access, no filtering, one week' do
      let(:params) { default_params }

      it 'creates a token with requires_ip_filtering' do
        expect(token.name).to eq('Test')
        expect(token.write_access?).to be true
        expect(token.full_access?).to be true
        expect(token.authorized_networks).to be_blank
        expect(token.expires_at).to eq(1.week.from_now.to_date)
        expect(token.requires_ip_filtering).to be true
      end
    end

    context 'with read access' do
      let(:params) { default_params.merge(access: 'read') }

      it { expect(token.write_access?).to be false }
    end

    APIToken.selectable_lifetimes.each do |lifetime, duration|
      context "with the #{lifetime} lifetime" do
        let(:params) { default_params.merge(lifetime:) }

        it { expect(token.expires_at).to eq(duration.from_now.to_date) }
      end
    end

    context 'with a custom lifetime' do
      let(:params) { default_params.merge(lifetime: 'custom', customLifetime: 3.months.from_now.to_date.iso8601) }

      it { expect(token.expires_at).to eq(3.months.from_now.to_date) }
    end

    context 'with an invalid lifetime' do
      let(:params) { default_params.merge(lifetime: 'infinite') }

      it 'does not create a token and renders the security step again' do
        expect(token).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:securite)
      end
    end

    context 'with network filtering' do
      let(:networks) { '192.168.1.23/32 2001:41d0:304:400::52f/128' }
      let(:params) { default_params.merge(networkFiltering: 'customNetworks', networks:) }

      it {
  expect(token.authorized_networks).to eq([
    IPAddr.new('192.168.1.23/32'),
    IPAddr.new('2001:41d0:304:400::52f/128'),
  ])
}
    end

    context 'with network filtering and a one year lifetime' do
      let(:networks) { '192.168.1.23/32 2001:41d0:304:400::52f/128' }
      let(:params) { default_params.merge(networkFiltering: 'customNetworks', networks:, lifetime: 'oneYear') }

      it { expect(token.expires_at).to eq(APIToken::LIFETIMES[:oneYear].from_now.to_date) }
    end

    context 'with procedure filtering' do
      let(:params) { default_params.merge(target: 'custom', targets: [procedure.id]) }

      it do
        expect(token.allowed_procedure_ids).to eq([procedure.id])
        expect(token.full_access?).to be false
      end
    end

    context 'with procedure filtering on a procedure not owned by the admin' do
      let(:another_procedure) { create(:procedure, :new_administrateur) }
      let(:params) { default_params.merge(target: 'custom', targets: [another_procedure.id]) }

      it 'does not create a token without access and renders the autorisations step again' do
        expect(token).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:autorisations)
      end
    end

    context 'with procedure filtering on a forged targets string' do
      let(:params) { default_params.merge(target: 'custom', targets: procedure.id.to_s) }

      it do
        expect(token).to be_nil
        expect(response).to render_template(:autorisations)
      end
    end
  end

  describe 'securite' do
    render_views

    it 'carries the targeted procedures over to the creation form and the back link' do
      get :securite, params: { name: 'Test', access: 'read', target: 'custom', targets: [procedure.id] }

      form = response.parsed_body
      expect(form.css("input[type=hidden][name='targets[]']").map { it['value'] }).to eq([procedure.id.to_s])
      back_link = form.at_css("a[href^='#{autorisations_admin_api_tokens_path}']")['href']
      expect(Rack::Utils.parse_nested_query(URI(back_link).query)['targets']).to eq([procedure.id.to_s])
    end

    it 'ignores a forged targets hash' do
      get :securite, params: { name: 'Test', target: 'custom', targets: { a: procedure.id } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("input[name='targets[]']")).to be_empty
    end

    it 'tells the admin the networks are invalid and keeps the targeted procedures' do
      post :create, params: { name: 'Test', access: 'read', target: 'custom', targets: [procedure.id], networkFiltering: 'customNetworks', networks: 'bad', lifetime: 'oneWeek' }

      expect(response.parsed_body.at_css('.fr-error-text').text).to eq('Vous devez entrer des adresses IPv4 ou IPv6 valides')
      form = response.parsed_body.at_css("form[action='#{admin_api_tokens_path}']")
      expect(form.css("input[type=hidden][name='targets[]']").map { it['value'] }).to eq([procedure.id.to_s])
    end
  end

  describe 'autorisations' do
    render_views

    it 'tells the admin to pick a procedure' do
      post :create, params: { name: 'Test', access: 'read', target: 'custom', lifetime: 'oneWeek' }

      error = response.parsed_body.at_css('fieldset.fr-fieldset--error .fr-messages-group .fr-message--error')
      expect(error.text.strip).to eq('Sélectionnez au moins une démarche')
    end
  end

  describe 'update' do
    let(:token) { APIToken.generate(admin).first }
    let(:params) { { name:, networks:, procedure_to_add: } }
    let(:name) { 'new name' }
    let(:networks) { '118.218.200.200' }
    let(:procedure_to_add) { nil }

    subject { patch :update, params: params.merge(id: token.id) }

    context 'nominal' do
      before { subject; token.reload }

      it 'updates a token' do
        expect(token.name).to eq('new name')
        expect(token.authorized_networks).to eq([IPAddr.new('118.218.200.200')])
      end
    end

    context 'with bad network' do
      let(:networks) { 'bad' }

      before { subject; token.reload }

      it 'does not update a token' do
        expect(token.authorized_networks).to be_blank
        expect(assigns(:invalid_network_message)).to eq('vous devez entrer des adresses ipv4 ou ipv6 valides')
      end
    end

    # Tokens predating automatic IP pinning never re-pin themselves, so they must
    # always keep at least one network. Keyed on requires_ip_filtering rather
    # than on the expiration date, which the backfill is about to fill in for
    # every token.
    context 'with no network on a token without automatic IP pinning' do
      before do
        token.update!(authorized_networks: [IPAddr.new('118.218.200.200')])
        token.update_column(:requires_ip_filtering, false)
        subject
        token.reload
      end

      let(:networks) { '' }

      it 'does not update a token' do
        expect(token.authorized_networks).to eq([IPAddr.new('118.218.200.200')])
        expect(assigns(:invalid_network_message)).to eq("Vous ne pouvez pas supprimer les restrictions d’accès à l’API d’un jeton permanent.")
      end
    end

    context 'with a legitime procedure to add' do
      let(:params) { { procedure_to_add: procedure.id } }

      before { subject; token.reload }

      it { expect(token.allowed_procedure_ids).to eq([procedure.id]) }
    end

    context 'with a procedure to add not owned by the admin' do
      let(:another_procedure) { create(:procedure, administrateurs: [create(:administrateur)]) }
      let(:params) { { procedure_to_add: another_procedure.id } }

      before { subject; token.reload }

      it { expect(token.allowed_procedure_ids).to eq([]) }
    end

    context 'with an empty procedure to add' do
      let(:params) { { procedure_to_add: '' } }

      before { subject; token.reload }

      it { expect(token.allowed_procedure_ids).to eq([]) }
    end

    context 'with restore_full_access' do
      let(:params) { { restore_full_access: true } }

      before do
        token.update!(allowed_procedure_ids: [procedure.id])
        subject
        token.reload
      end

      it 'restores full access' do
        expect(token.allowed_procedure_ids).to be_nil
        expect(token.full_access?).to be true
      end
    end
  end

  describe 'nom' do
    render_views

    subject { get :nom, params: }

    let(:name_field) { response.parsed_body.at_css("input[name='name']") }

    context 'when duplicating an existing token' do
      let(:token) { APIToken.generate(admin).first }
      let(:params) do
        token.update!(name: 'Jeton à dupliquer', write_access: true, allowed_procedure_ids: [procedure.id])
        APITokenForm.from_token(token).to_h
      end

      it 'pre-fills the name from the original token' do
        subject
        expect(name_field['value']).to eq('Jeton à dupliquer')
      end
    end

    context 'without duplication' do
      let(:params) { {} }

      it 'starts with a blank name' do
        subject
        expect(name_field['value']).to be_nil
      end
    end
  end

  describe 'remove_procedure' do
    # a full-access token materializes all the admin's procedures on removal:
    # use the seeded blank administrateur, who is guaranteed to own nothing
    let(:admin) { administrateurs.blank }
    let!(:procedure1) { create(:procedure, administrateurs: [admin]) }
    let!(:procedure2) { create(:procedure, administrateurs: [admin]) }
    let(:token) { APIToken.generate(admin).first }

    subject { delete :remove_procedure, params: { id: token.id, procedure_id: procedure1.id } }

    context 'with all procedures allowed' do
      it do
        expect(token.allowed_procedure_ids).to be_nil
        subject
        token.reload
        expect(token.allowed_procedure_ids).to eq([procedure2.id])
      end
    end

    context 'with an existing procedure list' do
      before do
        token.update!(allowed_procedure_ids: [procedure1.id, procedure2.id])
      end

      it do
        subject
        token.reload
        expect(token.allowed_procedure_ids).to eq([procedure2.id])
      end

      context 'when the procedure requires ProConnect' do
        before { procedure1.enable_pro_connect_restriction!(:instructeurs) }

        it 'still removes it from the token' do
          subject
          expect(token.reload.allowed_procedure_ids).to eq([procedure2.id])
        end
      end
    end

    context 'when removing the last allowed procedure' do
      before do
        token.update!(allowed_procedure_ids: [procedure1.id])
      end

      it 'persists an empty list instead of silently restoring full access' do
        subject
        token.reload
        expect(token.allowed_procedure_ids).to eq([])
        expect(token.full_access?).to be false
      end
    end
  end
end
