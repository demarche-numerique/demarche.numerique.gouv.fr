# frozen_string_literal: true

module Maintenance
  class T20260828RepairDepartementAndEpciChampsTask < MaintenanceTasks::Task
    # Entre la mise en production de Rails 8.1 et son correctif, la
    # normalisation de `value` repassait par les accesseurs publics : les
    # writers des champs département et EPCI étaient rappelés avec leur propre
    # sortie — un nom — et la ré-interprétaient comme un code, laissant le nom
    # dans `external_id` et une `value` vide.
    #
    # `index_champs_on_type` imposerait une seule requête de plusieurs minutes,
    # ni `external_id` ni `value` n'étant indexés : le découpage par stable_id
    # borne chaque requête. Compter ~15 min de balayage, rejoué à chaque
    # reprise du job.

    include StatementsHelpersConcern

    # mise en production de Rails 8.1 ; pas de borne haute, un buffer fusionné,
    # un dossier cloné ou un simple ré-enregistrement donnent à une ligne
    # corrompue un `updated_at` postérieur au correctif sans la réparer
    CORRUPTED_SINCE = '2026-08-26 12:30'
    DEPARTEMENT_NAMES_AS_SHORT_AS_A_CODE = %w[Ain Lot Var].freeze
    EPCI_CODE_FORMAT = '^[0-9]{9}$'
    SLICE_SIZE = 50
    SLICE_TIMEOUT = '5min'

    def collection
      ChampData.where(id: corrupted_departement_ids + corrupted_epci_ids)
    end

    def process(champ)
      case champ
      when Champs::DepartementChamp then repair_departement(champ)
      when Champs::EpciChamp then repair_epci(champ)
      end
    end

    private

    def corrupted_departement_ids
      corrupted_ids(:departements, ChampData.where(value: nil, external_id: DEPARTEMENT_NAMES_AS_SHORT_AS_A_CODE))
    end

    def corrupted_epci_ids
      corrupted_ids(:epci, ChampData.where(value: nil).where.not(external_id: [nil, '']).where("external_id !~ ?", EPCI_CODE_FORMAT))
    end

    def corrupted_ids(type_champ, corrupted)
      corrupted = corrupted.where(updated_at: Time.zone.parse(CORRUPTED_SINCE)..)

      stable_ids(type_champ).each_slice(SLICE_SIZE).flat_map do |slice|
        with_statement_timeout(SLICE_TIMEOUT) { corrupted.where(stable_id: slice).pluck(:id) }
      end
    end

    def stable_ids(type_champ)
      TypeDeChamp.where(type_champ:).distinct.pluck(:stable_id).compact
    end

    def repair_departement(champ)
      name = champ.external_id
      code = APIGeoService.departement_code(name)
      return if code.nil?

      region_code = APIGeoService.region_code_by_departement(code)

      champ.update_columns(
        external_id: code,
        value: name,
        value_json: champ.value_json.to_h.merge('department_code' => code, 'region_code' => region_code, 'code_region' => region_code)
      )
      champ.dossier.index_search_terms_later
    end

    def repair_epci(champ)
      # APIGeoService.epcis lève sans département exploitable
      return if champ.code_departement.blank? || champ.code_departement == '99'

      name = champ.external_id
      code = APIGeoService.epci_code(champ.code_departement, name)
      return if code.nil?

      champ.update_columns(external_id: code, value: name)
      champ.dossier.index_search_terms_later
    end
  end
end
