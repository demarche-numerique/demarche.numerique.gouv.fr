# frozen_string_literal: true

describe "Connecting an instructeur to RDV Service Public" do
  it "sends RDV Service Public a callback URL on the app's host" do
    host! "test.host"
    post "/auth/rdvservicepublic"

    expect(response.location).to include("redirect_uri=#{CGI.escape("http://test.host/auth/rdvservicepublic/callback")}")
  end

  it "accepts the legacy host" do
    host! "test-legacy.host"
    post "/auth/rdvservicepublic"

    expect(response.location).to include("redirect_uri=#{CGI.escape("http://test-legacy.host/auth/rdvservicepublic/callback")}")
  end

  it "refuses a forged host instead of sending it to RDV Service Public" do
    host! "evil.example"
    post "/auth/rdvservicepublic"

    expect(response).to redirect_to("/auth/failure?message=invalid_host&strategy=rdvservicepublic")
  end
end
