# frozen_string_literal: true

describe APIEntreprise::API do
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }
  let(:siren) { '111111111' }

  def fixture_file(filename) = Rails.root.join('spec/fixtures/files/api_entreprise', filename).read

  describe '.etablissement' do
    let(:siret) { '41816609600051' }
    let(:etablissement_url) { "https://entreprise.api.gouv.fr/v4/insee/sirene/etablissements/#{siret}" }

    subject { described_class.new(procedure_id).etablissement(siret) }

    before do
      stub_request(:get, etablissement_url)
        .with(query: { "non_diffusables" => "true", "context" => APPLICATION_NAME, "object" => "procedure_id: #{procedure_id}", "recipient" => ENV.fetch("API_ENTREPRISE_DEFAULT_SIRET") })
        .to_return(status:, body:)
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
    end

    context 'when siret exists' do
      let(:status) { 200 }
      let(:body) { fixture_file('etablissements.json') }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end

      context 'with a service without siret' do
        let(:procedure) { create(:procedure, :with_service) }
        let(:dinum_siret) { "13002526500013" }

        it 'sends default recipient' do
          ENV["API_ENTREPRISE_DEFAULT_SIRET"] = dinum_siret
          procedure.service.siret = nil
          procedure.service.save(validate: false)
          subject
          expect(WebMock).to have_requested(:get, etablissement_url).with(query: hash_including({ recipient: dinum_siret }))
        end
      end

      context 'with a service with siret not matching the queried siret' do
        let(:procedure) { create(:procedure, :with_service) }

        it 'sends the service siret as recipient' do
          subject
          expect(WebMock).to have_requested(:get, etablissement_url).with(query: hash_including({ recipient: procedure.service.siret }))
        end
      end
    end

    context 'when siret does not exist' do
      let(:status) { 404 }
      let(:body) { '' }

      it 'returns a Failure with type :not_found' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :not_found, code: 404, retryable: false)
      end
    end

    context 'when the API answers 409' do
      let(:status) { 409 }
      let(:body) { '' }

      it 'is retryable: the conflict is on their side' do
        expect(subject.failure).to include(type: :conflict, code: 409, retryable: true)
      end
    end

    context 'when the API answers 200 with a body that is not JSON' do
      let(:status) { 200 }
      let(:body) { 'not json' }

      it 'is retryable: they will fix their payload' do
        expect(subject.failure).to include(type: :json, code: 200, retryable: true)
      end
    end

    context 'when the API answers 200 with a JSON scalar' do
      let(:status) { 200 }
      let(:body) { 'null' }

      it 'is retryable: they will fix their payload' do
        expect(subject.failure).to include(type: :unexpected_type, code: 200, retryable: true)
      end
    end

    context 'when forbidden (403)' do
      let(:status) { 403 }
      let(:body) { fixture_file('entreprises_private.json') }

      it 'returns a Failure with type :forbidden' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :forbidden, code: 403, retryable: false)
      end
    end

    context 'when rate limited (429)' do
      let(:status) { 429 }
      let(:body) { '{"errors":[{"code":"00429","title":"Trop de requêtes"}]}' }

      it 'returns a Failure with type :rate_limited' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :rate_limited, code: 429, retryable: true)
      end
    end

    context 'when unavailable for legal reasons (451)' do
      let(:status) { 451 }
      let(:body) { '{"errors":[{"code":"00451","title":"Indisponible pour raisons légales"}]}' }

      it 'returns a Failure with type :unavailable_for_legal_reasons' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :unavailable_for_legal_reasons, code: 451, retryable: false)
      end
    end

    context 'when undocumented HTTP code (400)' do
      let(:status) { 400 }
      let(:body) { '' }

      it 'returns a Failure with type :server_error' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :server_error, code: 400, retryable: true)
      end
    end

    context 'when server error (500)' do
      let(:status) { 500 }
      let(:body) { fixture_file('error_500.html') }

      it 'returns a Failure with type :server_error' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :server_error, code: 500, retryable: true)
      end
    end

    context 'when bad gateway (502) without service_unavailable error code' do
      let(:status) { 502 }
      let(:body) { fixture_file('entreprises_unavailable.json') }

      it 'returns a Failure with type :server_error' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :server_error, code: 502, retryable: true)
      end
    end

    context 'when bad gateway (502) with error code 01000' do
      let(:status) { 502 }
      let(:body) { fixture_file('error_code_01000.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end

    context 'when bad gateway (502) with error code 01001' do
      let(:status) { 502 }
      let(:body) { fixture_file('error_code_01001.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end

    context 'when gateway timeout (504) with error code 01002' do
      let(:status) { 504 }
      let(:body) { fixture_file('error_code_01002.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end

    context 'when gateway timeout (504) with error code 02002' do
      let(:status) { 504 }
      let(:body) { fixture_file('error_code_02002.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end

    context 'when gateway timeout (504) with error code 03002' do
      let(:status) { 504 }
      let(:body) { fixture_file('error_code_03002.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end

    context 'when service unavailable (503) with error code 03020' do
      let(:status) { 503 }
      let(:body) { fixture_file('error_code_03020.json') }

      it 'returns a Failure with type :service_unavailable' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :service_unavailable, retryable: true)
      end
    end
  end

  describe '.etablissement network errors' do
    let(:siret) { '41816609600051' }
    subject { described_class.new(procedure_id).etablissement(siret) }

    context 'when the request times out' do
      before do
        allow_any_instance_of(API::Client).to receive(:call).and_return(
          Dry::Monads::Failure(API::Client::Error[:timeout, 0, true, API::Client::HTTPError.new(
            Typhoeus::Response.new(effective_url: "https://entreprise.api.gouv.fr/v4/insee/sirene/etablissements/#{siret}", code: 0, body: '', return_message: 'Timeout', total_time: 20, connect_time: 1, headers: '')
          )])
        )
      end

      it 'returns a Failure with type :timeout and retryable true' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :timeout, retryable: true)
      end
    end
  end

  describe '.exercices' do
    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/dgfip\/etablissements\/#{siret}\/chiffres_affaires/)
        .to_return(status: status, body: body)
    end

    context 'when siret does not exist' do
      subject { described_class.new(procedure_id).exercices(siret) }

      let(:siret) { '11111111111111' }
      let(:status) { 404 }
      let(:body) { '' }

      it 'returns a Failure with type :not_found' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :not_found, code: 404)
      end
    end

    context 'when siret exists' do
      subject { described_class.new(procedure_id).exercices(siret) }

      let(:siret) { '41816609600051' }
      let(:status) { 200 }
      let(:body) { fixture_file('exercices.json') }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end
    end
  end

  describe '.rna' do
    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{siren}/)
        .to_return(status: status, body: body)
    end

    subject { described_class.new(procedure_id).rna(siren) }

    context 'when siren does not exist' do
      let(:siren) { '111111111' }
      let(:status) { 404 }
      let(:body) { '' }

      it 'returns a Failure with type :not_found' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :not_found, code: 404)
      end
    end

    context 'when siren exists' do
      let(:siren) { '418166096' }
      let(:status) { 200 }
      let(:body) { fixture_file('associations.json') }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end

      context 'with a service siret sharing the same siren' do
        let(:procedure) { create(:procedure, :with_service) }
        let(:siren) { procedure.service.siret[0..8] }
        let(:dinum_siret) { "13002526500013" }

        it 'sends default recipient to avoid self-referencing' do
          ENV["API_ENTREPRISE_DEFAULT_SIRET"] = dinum_siret
          subject
          expect(WebMock).to have_requested(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{siren}/)
            .with(query: hash_including({ recipient: dinum_siret }))
        end
      end

      context 'with a service siret from a different siren' do
        let(:procedure) { create(:procedure, :with_service) }

        it 'sends the service siret as recipient' do
          subject
          expect(WebMock).to have_requested(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{siren}/)
            .with(query: hash_including({ recipient: procedure.service.siret }))
        end
      end
    end
  end

  describe '.attestation_sociale' do
    let(:siren) { '418166096' }
    let(:status) { 200 }
    let(:body) { fixture_file('attestation_sociale.json') }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:can_fetch_attestation_sociale?).and_return(can_fetch)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/urssaf\/unites_legales\/#{siren}\/attestation_vigilance/)
        .to_return(body: body, status: status)
    end

    subject { described_class.new(procedure.id).attestation_sociale(siren) }

    context 'when token not authorized' do
      let(:can_fetch) { false }

      it 'returns a Failure with type :forbidden' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :forbidden, code: 403, retryable: false)
      end
    end

    context 'when token is authorized' do
      let(:can_fetch) { true }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end
    end
  end

  describe '.attestation_fiscale' do
    let(:siren) { '418166096' }
    let(:user_id) { 1 }
    let(:status) { 200 }
    let(:body) { fixture_file('attestation_fiscale.json') }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:can_fetch_attestation_fiscale?).and_return(can_fetch)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/dgfip\/unites_legales\/#{siren}\/attestation_fiscale/)
        .to_return(body:, status:)
    end

    subject { described_class.new(procedure.id).attestation_fiscale(siren, user_id) }

    context 'when token not authorized' do
      let(:can_fetch) { false }

      it 'returns a Failure with type :forbidden' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :forbidden, code: 403, retryable: false)
      end
    end

    context 'when token is authorized' do
      let(:can_fetch) { true }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end
    end
  end

  describe '.bilans_bdf' do
    let(:siren) { '418166096' }
    let(:status) { 200 }
    let(:body) { fixture_file('bilans_entreprise_bdf.json') }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:can_fetch_bilans_bdf?).and_return(can_fetch)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/banque_de_france\/unites_legales\/#{siren}\/bilans/)
        .to_return(body: body, status: status)
    end

    subject { described_class.new(procedure.id).bilans_bdf(siren) }

    context 'when token not authorized' do
      let(:can_fetch) { false }

      it 'returns a Failure with type :forbidden' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :forbidden, code: 403, retryable: false)
      end
    end

    context 'when token is authorized' do
      let(:can_fetch) { true }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end
    end
  end

  describe '.privileges' do
    let(:api) { described_class.new }
    let(:status) { 200 }
    let(:body) { fixture_file('privileges.json') }
    subject { api.privileges }

    before do
      api.token = APIEntrepriseToken.new(nil)

      allow(api.token).to receive(:jwt_token).and_return(double(blank?: blank))
      allow(api.token).to receive(:expired?).and_return(expired)

      stub_request(:get, "https://entreprise.api.gouv.fr/privileges")
        .to_return(body: body, status: status)
    end

    context 'with a blank token' do
      let(:blank) { true }
      let(:expired) { false }

      it 'returns a Failure with type :token_missing' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :token_missing, code: 401, retryable: false)
      end
    end

    context 'with a expired token' do
      let(:blank) { false }
      let(:expired) { true }

      it 'returns a Failure with type :token_expired' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :token_expired, code: 401, retryable: false)
      end
    end

    context 'with a valid token' do
      let(:blank) { false }
      let(:expired) { false }

      it 'returns Success with body' do
        expect(subject).to be_success
        expect(subject.value!).to eq(JSON.parse(body, symbolize_names: true))
      end
    end
  end

  describe 'rate limiting' do
    let(:siret) { '41816609600051' }
    let(:body) { fixture_file('etablissements.json') }
    let(:pool) { APIEntreprise::API::DEFAULT_POOL }
    let(:rate_limit_headers) { { 'RateLimit-Remaining' => '47', 'RateLimit-Limit' => pool.to_s, 'RateLimit-Reset' => reset_timestamp.to_s } }
    let(:reset_timestamp) { Time.current.to_i + 30 }

    before do
      Kredis.redis.del(APIEntreprise::RateLimiter.remaining_key(pool), APIEntreprise::RateLimiter.reset_key(pool))
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
    end

    describe 'RateLimiter.calibrate! via response headers' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body:, status:, headers: rate_limit_headers)
      end

      context 'when API returns 200 with RateLimit headers' do
        let(:status) { 200 }

        it 'stores remaining in Redis (reset not stored when remaining > 0)' do
          described_class.new(procedure_id).etablissement(siret)

          expect(Kredis.redis.get(APIEntreprise::RateLimiter.remaining_key(pool)).to_i).to eq(47)
          expect(Kredis.redis.get(APIEntreprise::RateLimiter.reset_key(pool))).to be_nil
        end

        it 'sets TTL on Redis keys' do
          described_class.new(procedure_id).etablissement(siret)

          ttl = Kredis.redis.ttl(APIEntreprise::RateLimiter.remaining_key(pool))
          expect(ttl).to be_between(1, 30)
        end
      end

      context 'when API returns 200 without RateLimit headers' do
        let(:status) { 200 }
        let(:rate_limit_headers) { {} }

        it 'does not write to Redis' do
          described_class.new(procedure_id).etablissement(siret)

          expect(Kredis.redis.get(APIEntreprise::RateLimiter.remaining_key(pool))).to be_nil
        end
      end

      context 'when API returns 429 with RateLimit-Reset header' do
        let(:status) { 429 }
        let(:body) { '{"errors":[{"code":"00429","title":"Trop de requêtes"}]}' }
        let(:rate_limit_headers) { { 'RateLimit-Remaining' => '0', 'RateLimit-Reset' => reset_timestamp.to_s } }

        it 'calibrates remaining to 0 and stores reset timestamp' do
          described_class.new(procedure_id).etablissement(siret)

          expect(Kredis.redis.get(APIEntreprise::RateLimiter.remaining_key(pool)).to_i).to eq(0)
          expect(Kredis.redis.get(APIEntreprise::RateLimiter.reset_key(pool)).to_i).to eq(reset_timestamp)
        end
      end
    end
  end

  describe 'with expired token' do
    let(:siret) { '41816609600051' }
    subject { described_class.new(procedure_id).etablissement(siret) }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(true)
    end

    it 'returns a Failure with type :token_expired and makes no call to api-entreprise' do
      expect(subject).to be_failure
      expect(subject.failure).to include(type: :token_expired, code: 401, retryable: false)
      expect(WebMock).not_to have_requested(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
    end
  end
end
