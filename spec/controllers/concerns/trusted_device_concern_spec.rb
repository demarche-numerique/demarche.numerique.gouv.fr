# frozen_string_literal: true

# Covers only what the revocation counter adds. Whose cookie it is, and the
# adoption of cookies issued before the instructeur id was stored, belong to
# spec/requests/trusted_device_spec.rb.
describe TrustedDeviceConcern, type: :controller do
  controller(ApplicationController) do
    skip_before_action :redirect_if_untrusted, raise: false

    def trust
      trust_device(Time.zone.now, current_instructeur)
      head(:ok)
    end

    def check
      head(trusted_device? ? :ok : :forbidden)
    end
  end

  let(:instructeur) { create(:instructeur) }
  let(:user) { instructeur.user }

  before do
    routes.draw do
      get 'trust' => 'anonymous#trust'
      get 'check' => 'anonymous#check'
    end
    sign_in(user)
  end

  context 'once the device is trusted' do
    before { get :trust }

    it 'trusts it' do
      get :check

      expect(response).to have_http_status(:ok)
    end

    # The whole point: before the counter, the cookie was self-asserting and no
    # revocation could reach it -- a stolen one was worth a month of skipping
    # the email token.
    it 'stops trusting it once every session is revoked' do
      user.revoke_sessions!(reason: :logout_all)
      # Warden keeps the same instance between two requests of a controller spec,
      # where production deserialises the record afresh on each one.
      sign_in(user.reload)

      get :check

      expect(response).to have_http_status(:forbidden)
    end

    it 'keeps trusting it when a single device is closed elsewhere' do
      user.revoke_sessions!(reason: :logout_device)
      sign_in(user.reload)

      get :check

      expect(response).to have_http_status(:ok)
    end

    it 'stamps the counter of the instructeur it is told about' do
      payload = JSON.parse(@controller.send(:cookies).encrypted[TrustedDeviceConcern::TRUSTED_DEVICE_COOKIE_NAME])

      expect(payload['version']).to eq(user.trusted_device_version)
    end
  end

  it 'destroys the pending email tokens on a total revocation' do
    instructeur.create_trusted_device_token

    expect { user.revoke_sessions!(reason: :support) }
      .to change { instructeur.trusted_device_tokens.count }.to(0)
  end

  # A cookie written before the counter existed reads as zero. Adopting it on a
  # bumped counter would hand back the trust the revocation had just cut, so the
  # check has to sit above the adoption rather than inside it.
  context 'with a cookie predating the counter' do
    let(:created_at) { 2.days.ago.change(usec: 0) }

    before do
      instructeur.trusted_device_tokens.create!(created_at:, activated_at: created_at)
      request.cookie_jar.encrypted[TrustedDeviceConcern::TRUSTED_DEVICE_COOKIE_NAME] =
        JSON.generate({ created_at: })
    end

    it 'adopts it while no revocation has happened' do
      get :check

      expect(response).to have_http_status(:ok)
    end

    it 'refuses it once a revocation has bumped the counter' do
      user.revoke_sessions!(reason: :support)
      sign_in(user.reload)

      get :check

      expect(response).to have_http_status(:forbidden)
    end
  end
end
