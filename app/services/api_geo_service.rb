# frozen_string_literal: true

class APIGeoService
  # Excluded from country list (French overseas departments that are not sovereign countries)
  EXCLUDED_COUNTRY_CODES = %w[GP MQ GF RE YT].freeze

  class << self
    def degraded_mode?
      ENV.enabled?('API_GEO_DEGRADED_MODE')
    end

    def countries(locale: I18n.locale)
      memoize(:countries, locale) do
        I18nData.countries(locale)
          .merge(get_localized_additional_countries(locale))
          .reject { |code, _name| code.in?(EXCLUDED_COUNTRY_CODES) }
          .map { |(code, name)| { name:, code: } }
          .sort_by { I18n.transliterate(_1[:name].tr('î', 'Î')) }
          .freeze
      end
    end

    def country_options = countries.map { [_1[:name], _1[:code]] }

    def country_name(code, locale: I18n.locale)
      countries(locale:).find { _1[:code] == code }&.dig(:name)
    end

    def country_code(name)
      return if name.nil?
      code = I18nData.country_code(name) || I18nData.country_code(name.humanize) || I18nData.country_code(name.titleize)
      if code.nil?
        countries_index_fr[I18n.transliterate(name).upcase]&.dig(:code)
      else
        code
      end
    end

    def regions
      memoize(:regions) do
        get_from_api_geo(:regions).sort_by { I18n.transliterate(_1[:name]) }.freeze
      end
    end

    def region_options = regions.map { [_1[:name], _1[:code]] }

    def region_name(code)
      regions.find { _1[:code] == code }&.dig(:name)
    end

    def region_code(name)
      return if name.nil?
      regions.find { _1[:name] == name }&.dig(:code)
    end

    def region_code_by_departement(code)
      return if code.nil?
      departements.find { _1[:code] == code }&.dig(:region_code)
    end

    def departements
      memoize(:departements) do
        ([{ code: '99', name: 'Etranger' }] + get_from_api_geo(:departements)).sort_by { _1[:code] }.freeze
      end
    end

    def departement_options
      departements.map { ["#{_1[:code]} – #{_1[:name]}", _1[:code]] }
    end

    def departement_name(code)
      return 'Etranger' if code == '99'
      departements.find { _1[:code] == code }&.dig(:name)
    end

    def departement_name_by_postal_code(postal_code)
      APIGeoService.departement_name(postal_code[0..2]) || APIGeoService.departement_name(postal_code[0..1])
    end

    def departement_code(name)
      return if name.nil?
      departements.find { _1[:name] == name }&.dig(:code)
    end

    def epcis(departement_code)
      memoize(:epcis, departement_code) do
        get_from_api_geo("epcis-#{departement_code}").sort_by { I18n.transliterate(_1[:name]) }.freeze
      end
    end

    def epci_name(departement_code, code)
      epcis(departement_code).find { _1[:code] == code }&.dig(:name)
    end

    def epci_code(departement_code, name)
      epcis(departement_code).find { _1[:name] == name }&.dig(:code)
    end

    def communes(departement_code)
      return [] if departement_code.blank? || departement_code == '99'

      memoize(:communes, departement_code) do
        get_from_api_geo("communes-#{departement_code}").sort_by { I18n.transliterate([_1[:name], _1[:postal_code]].join(' ')) }.freeze
      end
    end

    def communes_by_postal_code(postal_code)
      memoize(:communes_by_postal_code, postal_code) do
        communes_by_postal_code_map.fetch(postal_code, [])
          .filter { !_1[:code].in?(['75056', '13055', '69123']) }
          .sort_by { I18n.transliterate([_1[:name], _1[:postal_code]].join(' ')) }
          .freeze
      end
    end

    def commune_name(departement_code, code)
      communes(departement_code).find { _1[:code] == code }&.dig(:name)
    end

    def commune_by_name_or_postal_code(query)
      if postal_code?(query)
        fetch_by_postal_code(query)
      else
        fetch_by_name(query)
      end
    end

    def commune_code(departement_code, name)
      communes(departement_code).find { _1[:name] == name }&.dig(:code)
    end

    def commune_postal_codes(departement_code, code)
      communes(departement_code).filter { _1[:code] == code }.map { _1[:postal_code] }
    end

    def parse_ban_address(feature)
      return unless ban_address_schema.valid?(feature)

      properties = feature.fetch('properties')
      city_code = properties.fetch('citycode')

      territory = if properties['context'].present?
        department_code = properties.fetch('context').split(',').first
        region_code = region_code_by_departement(department_code)

        {
          department_name: departement_name(department_code),
          department_code:,
          region_name: region_name(region_code),
          region_code:,
          city_name: safely_normalize_city_name(department_code, city_code, properties['city']),
          city_code:,
          country_code: 'FR',
          country_name: country_name('FR'),
        }
      else
        {
          city_name: properties['city'],
          city_code:,
        }
      end

      {
        label: properties.fetch('label'),
        type: properties.fetch('type'),
        street_address: properties.fetch('name'),
        postal_code: properties.fetch('postcode') { '' }, # API graphql / serializer requires non-null data
        street_number: properties['housenumber'],
        street_name: properties['street'],
        geometry: feature['geometry'],
      }.merge(territory)
    end

    def clean_address_query(query)
      sanitized = query.to_s.strip
      sanitized = sanitized.gsub(/\s+/, " ")
      sanitized = sanitized.sub(/\A[^[:alnum:]]+/, "")

      return nil if sanitized.length < 3
      sanitized = sanitized[0...200] if sanitized.length > 200

      sanitized
    end

    def parse_rna_address(address)
      postal_code = address[:code_postal]
      city_name_fallback = address[:commune]
      city_code = address[:code_insee]
      department_code, region_code = if postal_code.present? && city_code.present?
        commune = communes_by_postal_code(postal_code).find { _1[:code] == city_code }
        if commune.present?
          [commune[:departement_code], commune[:region_code]]
        else
          []
        end
      end

      department_name = departement_name(department_code)
      {
        street_number: address[:numero_voie],
        street_name: address[:libelle_voie],
        street_address: address[:libelle_voie].present? ? [address[:numero_voie], address[:type_voie], address[:libelle_voie]].compact.join(' ') : nil,
        postal_code: postal_code.presence || '',
        city_name: safely_normalize_city_name(department_code, city_code, city_name_fallback),
        city_code: city_code.presence || '',
        departement_code: department_code,
        department_code:,
        departement_name: department_name,
        department_name:,
        region_code:,
        region_name: region_name(region_code),
        country_code: 'FR',
        country_name: country_name('FR'),
      }
    end

    def parse_rnf_address(address)
      postal_code = address[:postalCode]
      city_name_fallback = address[:cityName]
      city_code = address[:cityCode]
      department_code, region_code = if postal_code.present? && city_code.present?
        commune = communes_by_postal_code(postal_code).find { _1[:code] == city_code }
        if commune.present?
          [commune[:departement_code], commune[:region_code]]
        else
          []
        end
      end
      department_name = departement_name(department_code)

      {
        street_number: address[:streetNumber],
        street_name: address[:streetName],
        street_address: address[:streetAddress],
        postal_code: postal_code.presence || '',
        city_name: safely_normalize_city_name(department_code, city_code, city_name_fallback),
        city_code: city_code.presence || '',
        departement_code: department_code,
        department_code:,
        departement_name: department_name,
        department_name:,
        region_code:,
        region_name: region_name(region_code),
        country_code: 'FR',
        country_name: country_name('FR'),
      }
    end

    def parse_etablissement_address(etablissement)
      postal_code = etablissement.code_postal
      city_name_fallback = etablissement.localite.presence || ''
      city_code = etablissement.code_insee_localite
      department_code, region_code = if postal_code.present? && city_code.present?
        commune = communes_by_postal_code(postal_code).find { _1[:code] == city_code }
        if commune.present?
          [commune[:departement_code], commune[:region_code]]
        else
          []
        end
      end

      department_name = departement_name(department_code)

      {
        street_number: etablissement.numero_voie,
        street_name: etablissement.nom_voie,
        street_address: etablissement.nom_voie.present? ? [etablissement.numero_voie, etablissement.type_voie, etablissement.nom_voie].compact.join(' ') : nil,
        postal_code: postal_code.presence || '',
        city_name: safely_normalize_city_name(department_code, city_code, city_name_fallback),
        city_code: city_code.presence || '',
        departement_code: department_code,
        department_code:,
        departement_name: department_name,
        department_name:,
        region_code:,
        region_name: region_name(region_code),
        country_code: etablissement.nom_pays.present? ? nil : 'FR',
        country_name: etablissement.nom_pays || country_name('FR'),
      }
    end

    def parse_city_code_and_postal_code(code)
      if code.present? && code.match?(/-/)
        codes = code.split('-')
        return {} if codes.size != 2
        city_code = codes.first
        postal_code = codes.second
        commune = communes_by_postal_code(postal_code).find { _1[:code] == city_code }
        return {} if commune.blank?
        region_code = commune[:region_code]
        department_code = commune[:departement_code]

        {
          postal_code:,
          city_code:,
          city_name: commune[:name],
          department_code:,
          department_name: departement_name(department_code),
          region_code:,
          region_name: region_name(region_code),
          country_code: 'FR',
          country_name: country_name('FR'),
        }
      else
        {}
      end
    end

    def safely_normalize_city_name(department_code, city_code, fallback)
      return fallback if department_code.blank? || city_code.blank?

      commune_name(department_code, city_code) || fallback
    end

    def format_commune_response(results, with_combined_code)
      results.reject(&method(:code_metropole?)).flat_map do |result|
        item = {
          name: result[:nom].tr("'", '’'),
          code: result[:code],
        }.compact

        items = if result[:codesPostaux].present?
          result[:codesPostaux].map { item.merge(postal_code: _1) }
        else
          [item]
        end

        items.map do |item|
          label = "#{item[:name]} (#{item[:postal_code]})"
          if with_combined_code.present?
            {
              label:,
              value: "#{item[:code]}-#{item[:postal_code]}",
            }
          else
            {
              label:,
              value: item[:code],
              data: item[:postal_code],
            }
          end
        end
      end
    end

    def format_address_response(results)
      results[:features].flat_map do |feature|
        if feature[:properties][:type] == 'municipality'
          departement_code = feature[:properties][:context].split(',').first
          commune_postal_codes(departement_code, feature[:properties][:citycode]).map do |postcode|
            feature.deep_merge(properties: { postcode:, label: "#{feature[:properties][:label]} (#{postcode})" })
          end
        else
          feature
        end
      end.map do
        {
          label: _1[:properties][:label],
          value: _1[:properties][:label],
          data: parse_ban_address(_1.deep_stringify_keys),
        }
      end
    end

    def inline_service_public_address(address_data)
      return nil if address_data.blank?

      components = [
        address_data['numero_voie'],
        address_data['complement1'],
        address_data['complement2'],
        address_data['service_distribution'],
        address_data['code_postal'],
        address_data['nom_commune'],
      ].compact_blank

      components.join(' ')
    end

    private

    def code_metropole?(result)
      result[:code].in?(['75056', '13055', '69123'])
    end

    def communes_by_postal_code_map
      memoize(:communes_by_postal_code_map) do
        departements
          .filter { _1[:code] != '99' }
          .flat_map { communes(_1[:code]) }
          .group_by { _1[:postal_code] }
          .freeze
      end
    end

    def get_from_api_geo(scope)
      JSON.parse(Rails.root.join('lib', 'data', 'api_geo', "#{scope}.json").read, symbolize_names: true).freeze
    end

    def countries_index_fr
      memoize(:countries_index_fr) do
        countries(locale: 'FR').index_by { I18n.transliterate(_1[:name]).upcase }.freeze
      end
    end

    def get_localized_additional_countries(locale)
      additional_countries[locale.to_s.upcase] || {}
    end

    def additional_countries
      {
        'FR' => { 'XK' => 'Kosovo' },
        'EN' => { 'XK' => 'Kosovo' },
      }
    end

    private

    def reset_memo!
      @memo = nil
    end

    def memoize(*key)
      @memo ||= Concurrent::Map.new
      cached = @memo[key]
      return cached if !cached.nil?

      computed = yield
      @memo.put_if_absent(key, computed) || computed
    end

    def fetch_by_name(name)
      if degraded_mode?
        APIGeoDegradedService.fetch_communes_by_name(name, prepare_departements_data)
      else
        Typhoeus.get("#{API_GEO_URL}/communes", params: {
          type: 'commune-actuelle,arrondissement-municipal',
          nom: name,
          boost: 'population',
          limit: 100,
        }, timeout: 3)
      end
    end

    def fetch_by_postal_code(postal_code)
      if degraded_mode?
        APIGeoDegradedService.fetch_communes_by_postal_code(postal_code, prepare_departements_data)
      else
        Typhoeus.get("#{API_GEO_URL}/communes", params: {
          type: 'commune-actuelle,arrondissement-municipal',
          codePostal: postal_code,
          boost: 'population',
          limit: 50,
        }, timeout: 3)
      end
    end

    def prepare_departements_data
      memoize(:departements_data) do
        departements.each_with_object({}) do |departement, data|
          next if departement[:code] == '99'
          data[departement[:code]] = get_from_api_geo("communes-#{departement[:code]}")
        end.freeze
      end
    end

    def postal_code?(string)
      string.match?(/\A[-+]?\d+\z/) ? true : false
    end

    def ban_address_schema
      JSONSchemer.schema(Rails.root.join('app/schemas/adresse-ban.json'))
    end
  end
end
