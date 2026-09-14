# frozen_string_literal: true

class APIEntreprise::ServiceJob < APIEntreprise::Job
  def perform(service_id)
    service = Service.find(service_id)

    with_adapter(APIEntreprise::ServiceAdapter.new(service.siret, service_id)) do |service_params|
      service.etablissement_infos = service_params

      code_insee = service.etablissement_infos['code_insee_localite']
      nom_pays = service.etablissement_infos["nom_pays"]

      if code_insee.present?
        service.departement = CodeInsee.new(code_insee).to_departement
      elsif nom_pays.present? && nom_pays != "FRANCE"
        "99"
      end

      if service_params[:adresse].present?
        point = Geocoder.search(service_params[:adresse], params: { citycode: code_insee, limit: 1 }).first

        service.etablissement_lat = point&.latitude
        service.etablissement_lng = point&.longitude
      else
        service.etablissement_lat = nil
        service.etablissement_lng = nil
      end

      service.save!
    end
  end
end
