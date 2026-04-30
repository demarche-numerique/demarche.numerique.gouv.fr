# frozen_string_literal: true

describe FranceConnectService do
  describe '.authorization_uri' do
    let(:client) { instance_double('OpenIDConnect::Client') }
    let(:state) { 'a_state' }
    let(:nonce) { 'a_nonce' }
    let(:uri) { 'a_uri' }

    subject { described_class.authorization_uri }

    before do
      stub_const('FRANCE_CONNECT', identifier: 'identifier')
      allow(OpenIDConnect::Client).to receive(:new).and_return(client)
      allow(SecureRandom).to receive(:alphanumeric).with(32).and_return(state, nonce)
      allow(client).to receive(:authorization_uri).with(
        scope: [:identite_pivot, :email],
        state:, nonce:, acr_values: 'eidas1'
      )
        .and_return(uri)
    end

    it 'returns authorization uri' do
      expect(subject).to eq([uri, state, nonce])
    end
  end

  describe '.conf' do
    subject { described_class.send(:conf)[:redirect_uri] }

    before do
      stub_const('FRANCE_CONNECT', { redirect_uri: 'https://demarche.numerique.gouv.fr/france_connect/particulier/callback' })
      ENV['APP_HOST'] = 'demarche.numerique.gouv.fr'
      allow(Rails.env).to receive(:test?).and_return(false)
      Current.host = host
    end

    after { Current.host = nil }

    context 'when Current.host matches APP_HOST' do
      let(:host) { 'demarche.numerique.gouv.fr' }
      it { is_expected.to eq('https://demarche.numerique.gouv.fr/france_connect/particulier/callback') }
    end

    context 'when Current.host is an allowlisted alternate domain' do
      let(:host) { 'www.demarches-simplifiees.fr' }
      it { is_expected.to eq('https://www.demarches-simplifiees.fr/france_connect/particulier/callback') }
    end

    context 'when Current.host is a malicious lookalike (substring attack)' do
      let(:host) { 'demarche.numerique.gouv.fr.evil.com' }
      it 'does not substitute the host' do
        is_expected.to eq('https://demarche.numerique.gouv.fr/france_connect/particulier/callback')
      end
    end

    context 'when Current.host is an arbitrary unrelated host' do
      let(:host) { 'evil.com' }
      it { is_expected.to eq('https://demarche.numerique.gouv.fr/france_connect/particulier/callback') }
    end
  end

  describe '.retrieve_user_informations' do
    let(:code) { 'plop' }
    let(:given_name) { 'plop1' }
    let(:family_name) { 'plop2' }
    let(:birthdate) { '2012-12-31' }
    let(:gender) { 'plop4' }
    let(:birthplace) { 'plop5' }
    let(:birthcountry) { '99100' }
    let(:email) { 'plop@emaiL.com' }
    let(:phone) { '012345678' }
    let(:france_connect_particulier_id) { 'izhikziogjuziegj' }
    let(:nonce) { 'a_nonce' }
    let(:user_info_hash) {
      {
        'sub' => france_connect_particulier_id,
        'given_name' => given_name,
        'family_name' => family_name,
        'birthdate' => birthdate,
        'gender' => gender,
        'birthplace' => birthplace,
        'email' => email,
        'phone' => phone,
        'birthcountry' => birthcountry,
      }
    }
    let(:user_info) { instance_double('OpenIDConnect::ResponseObject::UserInfo', raw_attributes: user_info_hash) }

    subject { described_class.find_or_retrieve_france_connect_information(code, nonce) }

    before do
      access_token = instance_double('OpenIDConnect::AccessToken')
      allow_any_instance_of(OpenIDConnect::Client).to receive(:access_token!).and_return(access_token)
      allow(access_token).to receive(:userinfo!).and_return(user_info)
      allow(access_token).to receive(:id_token).and_return('id_token')

      allow(OpenIDConnect::ResponseObject::IdToken).to receive(:decode).and_return(double(verify!: true))
      stub_const('FRANCE_CONNECT', identifier: 'identifier')
    end

    context "when there is no existing fci" do
      it 'returns user informations' do
        fci, id_token = subject

        expect(fci).to have_attributes({
          given_name: given_name,
          family_name: family_name,
          birthdate: Time.zone.parse(birthdate).to_date,
          birthplace: birthplace,
          birthcountry: birthcountry,
          gender: gender,
          email_france_connect: email,
          france_connect_particulier_id: france_connect_particulier_id,
        })

        expect(id_token).to eq('id_token')
      end
    end

    context "when there is an existing fci with missing information" do
      let!(:fci) { create(:france_connect_information, france_connect_particulier_id:, given_name:, family_name:, birthdate:, gender:, email_france_connect: email) }

      it "add the missing information" do
        subject
        expect(fci.reload).to have_attributes({
          birthplace: birthplace,
          birthcountry: birthcountry,
        })
      end
    end

    context "when there is a complete fci with correct information" do
      let!(:fci) { create(:france_connect_information, france_connect_particulier_id:, given_name:, family_name:, birthdate:, gender:, email_france_connect: email, birthplace:, birthcountry:) }

      it "does not change the attributes" do
        expect { subject }.not_to change { fci.reload.attributes }
      end
    end
  end
end
