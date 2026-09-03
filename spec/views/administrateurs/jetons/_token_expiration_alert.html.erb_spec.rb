# frozen_string_literal: true

RSpec.describe 'administrateurs/jetons/_token_expiration_alert', type: :view do
  let(:token) { APIParticulierToken.new(jwt_token) }

  subject { render 'administrateurs/jetons/token_expiration_alert', token:, api_name: 'API Particulier', expected_format: 'API Particulier v3' }

  context "when there is no token" do
    let(:jwt_token) { nil }

    it "does not render anything" do
      subject
      expect(rendered).to be_empty
    end
  end

  context "when the token is a legacy key" do
    let(:jwt_token) { 'd7e9c9f4c3ca00caadde31f50fd4521a' }

    it "asks for a valid token, naming the expected format" do
      subject

      expect(rendered).to have_content("Votre jeton API Particulier n’est pas valide. Merci de le remplacer par un jeton valide (format API Particulier v3).", normalize_ws: true)
    end
  end

  context "when an API Entreprise token is invalid" do
    it "asks for a valid token without naming a format" do
      render 'administrateurs/jetons/token_expiration_alert', token: APIEntrepriseToken.new('not-a-token'), api_name: 'API Entreprise'

      expect(rendered).to have_content("Votre jeton API Entreprise n’est pas valide. Merci de le remplacer par un jeton valide.", normalize_ws: true)
      expect(rendered).not_to have_content("format")
    end
  end

  context "when the token is expired" do
    let(:jwt_token) { JWT.encode({ exp: 2.days.ago.to_i }, nil, "none") }

    it "should display an error" do
      subject

      expect(rendered).to have_content("Votre jeton API Particulier est expiré")
    end
  end

  context "when the token expires in few days it should display the expiration date" do
    let(:expiration) { 2.days.from_now }
    let(:jwt_token) { JWT.encode({ exp: expiration.to_i }, nil, "none") }

    it "should display an error" do
      subject

      expect(rendered).to have_content("Votre jeton API Particulier expirera le #{I18n.l(expiration, format: :long_with_time)}.", normalize_ws: true)
    end
  end

  context "when the token expires in a long time" do
    let(:expiration) { 2.months.from_now }
    let(:jwt_token) { JWT.encode({ exp: expiration.to_i }, nil, "none") }

    it "does not render anything" do
      subject
      expect(rendered).to be_empty
    end
  end
end
