# frozen_string_literal: true

module PrefillableFromServicePublicConcern
  extend ActiveSupport::Concern

  included do
    def prefill_from_siret
      future_sp = Concurrent::Future.execute { AnnuaireServicePublicService.new.call(siret:) }
      future_api_ent = Concurrent::Future.execute { APIRechercheEntreprisesService.new.call(siret:) }

      result_sp = future_sp.value!
      result_api_ent = future_api_ent.value!

      prefill_from_service_public(result_sp)
      prefill_from_api_entreprise(result_api_ent)

      [result_sp, result_api_ent]
    end

    private

    def prefill_from_service_public(result)
      case result
      in Dry::Monads::Success(data)
        self.nom = data[:nom] if nom.blank?
        self.email = data[:adresse_courriel] if email.blank?
        self.telephone = data[:telephone]&.first&.dig("valeur") if telephone.blank?
        self.horaires = denormalize_plage_ouverture(data[:plage_ouverture]) if horaires.blank?
        self.adresse = APIGeoService.inline_service_public_address(data[:adresse]&.first) if adresse.blank?
      else
        # NOOP
      end
    end

    def prefill_from_api_entreprise(result)
      case result
      in Dry::Monads::Success(data)
        self.type_organisme = detect_type_organisme(data) if type_organisme.blank?
        self.nom = data[:nom_complet] if nom.blank?
        self.adresse = data.dig(:siege, :geo_adresse) if adresse.blank?
      else
        # NOOP
      end
    end

    def denormalize_plage_ouverture(data)
      return if data.blank?

      data.map do |range|
        day_range = range.values_at('nom_jour_debut', 'nom_jour_fin').uniq.join(' au ')

        hours_range = (1..2).each_with_object([]) do |i, hours|
          start_hour = range["valeur_heure_debut_#{i}"]
          end_hour = range["valeur_heure_fin_#{i}"]

          if start_hour.present? && end_hour.present?
            hours << "de #{format_time(start_hour)} à #{format_time(end_hour)}"
          end
        end

        result = day_range
        result += " : #{hours_range.join(' et ')}" if hours_range.present?
        result += " (#{range['commentaire']})" if range['commentaire'].present?
        result
      end.join("\n")
    end

    def detect_type_organisme(data)
      # Cf https://recherche-entreprises.api.gouv.fr/docs/#tag/Recherche-textuelle/paths/~1search/get
      type = if data.dig(:complements, :collectivite_territoriale).present?
        :collectivite_territoriale
      elsif data.dig(:complements, :est_association)
        :association
      elsif data[:section_activite_principale] == "P"
        :etablissement_enseignement
      elsif data[:nom_complet].match?(/MINISTERE|MINISTERIEL/)
        :administration_centrale
      else # we can't differentiate between operateur d’état, administration centrale and service déconcentré de l’état, set the most frequent
        :service_deconcentre_de_l_etat
      end

      Service.type_organismes[type]
    end

    def format_time(str_time)
      Time.zone
        .parse(str_time)
        .strftime("%-H:%M")
    end
  end
end
