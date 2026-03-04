# frozen_string_literal: true

# Supprime les profils inactifs de Crisp page par page
#
# Bugs connus de l'API Crisp:
# - Le champ `updated_at` ne fonctionne pas correctement (tri et filtrage défaillants)
# - Le tri `sort_order: 'ascending'` provoque des erreurs et des résultats incorrects
# - Le champ `filter_date_end` concerne la date de création du profil
#
# Solution implémentée:
# - Utilisation du champ `active` (date de dernière activité)
# - Tri `descending`
# - Commence à la page 20 car les pages 1-19 sont des profils actifs récents.
#
# Un profil est considéré inactif si:
# - `active.last` est absent (nil), OU
# - `active.last < STALE_PERIOD`
#
class Cron::CrispDeleteInactivePeopleJob < Cron::CronJob
  include Dry::Monads[:result]

  self.schedule_expression = "every day at 3:30"

  queue_as :low

  INACTIVE_PERIOD = 1.month
  STARTING_PAGE = 20 # Skip les ~1000 premiers profils actifs (50/page * 20 pages)

  # Accepter le numéro de page (défaut STARTING_PAGE pour le démarrage cron)
  def perform(page_number = STARTING_PAGE)
    filter_date_end = INACTIVE_PERIOD.ago.to_date.iso8601
    stale_timestamp_ms = INACTIVE_PERIOD.ago.to_i * 1000
    @error_count = 0

    api = Crisp::APIService.new
    api_list_params = {
      per_page: 50,
      sort_field: 'active',
      sort_order: 'descending',
      filter_date_end:,
    }

    result = api.list_people_profiles(page_number, api_list_params)
    case result
    in Success(response)
      data = response[:data]

      # No more people
      return if data.empty?

      inactive_people = data.filter do |person|
        active = person[:active]
        next true if active[:last].nil?

        active[:last] < stale_timestamp_ms
      end

      people_ids = inactive_people.pluck(:people_id)
      people_ids.each do |people_id|
        result = api.delete_person(people_id:)

        if result.failure?
          handle_delete_failure(result, people_id, page_number)
        end

        sleep 0.5 # don't hit too much API
      end

      self.class.set(wait: people_ids.empty? ? 0.seconds : 10.seconds).perform_later(page_number + 1)
    in Failure(error:)
      Sentry.capture_message(error.message, extra: { page_number: })
    end
  end

  private

  def handle_delete_failure(result, people_id, page_number)
    @error_count += 1

    if @error_count > 3
      raise "Too many errors deleting Crisp people (page #{page_number}, #{@error_count} errors)"
    else
      Sentry.capture_message(
        "Failed to delete Crisp person",
        extra: { people_id:, error: result.failure, page_number: }
      )
    end
  end
end
