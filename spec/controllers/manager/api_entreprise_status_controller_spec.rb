# frozen_string_literal: true

describe Manager::APIEntrepriseStatusController, type: :controller do
  let(:super_admin) { create(:super_admin, :with_otp) }
  let(:etablissement) { dossiers.avec_siret.etablissement }

  around do |example|
    clear_health_checks
    example.run
    clear_health_checks
  end

  before { sign_in super_admin }

  def clear_health_checks
    APIEntreprise::HealthChecker::PROVIDERS.each_value do |key|
      Kredis.redis.del(APIEntreprise::HealthChecker.cache_key(key))
    end
  end

  render_views

  it 'shows the providers down and what waits in the parking' do
    Kredis.redis.set(APIEntreprise::HealthChecker.cache_key('banque_de_france/bilans'), 'bad_gateway', ex: 300)
    ParkedAPIEntrepriseFetch.park!(etablissement_id: etablissement.id, job: 'BilansBdfJob', procedure_id: procedures.entreprise.id,
      arguments: [etablissement.id, procedures.entreprise.id], code: 503)

    get :show

    expect(response).to have_http_status(:ok)
    expect(response.body.squish).to include('1 fournisseur en panne', 'Bilans (Banque de France)', 'bad_gateway', 'BilansBdfJob')
    expect(response.body).to include(APIEntreprise::Status::STATUS_PAGE_URL)
  end
end
