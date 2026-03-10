# frozen_string_literal: true

describe CookieOverflowHandler do
  describe "#call" do
    it "returns the downstream response when no overflow happens" do
      app = -> (_env) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
      middleware = described_class.new(app)
      env = Rack::MockRequest.env_for("/ping", method: "GET")

      status, headers, body = middleware.call(env)

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to eq("text/plain")
      expect(body).to eq(["ok"])
    end

    it "redirects to root and clears the overflowing cookie" do
      app = lambda do |_env|
        raise ActionDispatch::Cookies::CookieOverflow,
              "_test_cookie cookie overflowed with size 5000 bytes"
      end
      middleware = described_class.new(app)
      env = Rack::MockRequest.env_for("/users/sign_in", method: "POST")

      status, headers, body = middleware.call(env)

      expect(status).to eq(302)
      expect(headers).to include(
        "Location" => "/",
        "Content-Type" => "text/html",
        "Content-Length" => "0"
      )
      expect(headers["Set-Cookie"]).to eq(
        "_test_cookie=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"
      )
      expect(body).to eq([])
    end
  end
end
