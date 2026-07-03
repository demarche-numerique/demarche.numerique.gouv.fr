# frozen_string_literal: true

class AddressProxy
  ADDRESS_PARTS = [
    :street_address,
    :city_name,
    :postal_code,
    :city_code,
    :departement_name,
    :departement_code,
    :region_name,
    :region_code,
  ]

  class ChampAddressPresenter
    ADDRESS_PARTS.each do |address_part|
      define_method(address_part) do
        @data[address_part]
      end
    end

    def initialize(champ)
      @data = champ.value_json&.with_indifferent_access || {}
    end
  end

  class EtablissementAddressPresenter
    attr_reader(*ADDRESS_PARTS)

    def initialize(etablissement)
      @street_address = [etablissement.numero_voie, etablissement.type_voie, etablissement.nom_voie].compact.join(" ")
      @city_name = etablissement.localite
      @postal_code = etablissement.code_postal
      @city_code = etablissement.code_insee_localite
      if @postal_code
        @departement_name = APIGeoService.departement_name_by_postal_code(@postal_code)
        @departement_code = APIGeoService.departement_code(@departement_name)
        @region_code = APIGeoService.region_code_by_departement(@departement_code)
        @region_name = APIGeoService.region_name(@region_code)
      else # adresse without postal_code, ex:
        @departement_name, @departement_code, @region_code, @region_name = nil
      end
    end
  end

  delegate(*ADDRESS_PARTS, to: :@presenter)

  def initialize(champ_or_etablissement)
    @presenter = make(champ_or_etablissement)
  end

  def make(champ_or_etablissement)
    case champ_or_etablissement
    when Champ then ChampAddressPresenter.new(champ_or_etablissement)
    when Etablissement then EtablissementAddressPresenter.new(champ_or_etablissement)
    else raise NotImplementedError("Unsupported address from #{champ_or_etablissement.class.name}")
    end
  end
end
