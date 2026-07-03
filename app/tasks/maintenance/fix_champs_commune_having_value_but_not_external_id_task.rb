# frozen_string_literal: true

module Maintenance
  # some of our Champs::CommuneChamp had been corrupted, ie: missing external_id
  # this tasks fix this issue
  class FixChampsCommuneHavingValueButNotExternalIdTask < MaintenanceTasks::Task
    DEFAULT_INSTRUCTEUR_EMAIL = ENV.fetch('DEFAULT_INSTRUCTEUR_EMAIL') { CONTACT_EMAIL }

    def collection
      Champs::CommuneChamp.select(:id, :value, :external_id, :dossier_id, :stable_id, :row_id, :stream)
    end

    def process(champ_data)
      champ = Champ.from_data(champ_data)
      return if champ.nil?
      return if !(champ.value.present? && champ.external_id.blank?)
      champ.reload
      return if !fixable?(champ)

      response = APIGeoService.commune_by_name_or_postal_code(champ.value)
      if !response.success?
        notify("Strange case of existing commune not requestable", champ)
      else
        results = JSON.parse(response.body, symbolize_names: true)
        formated_results = APIGeoService.format_commune_response(results, true)
        case formated_results.size
        when 1
          champ.code = formated_results.first[:value]
          champ.save!
        else # otherwise, we can't find the expected departement
          if champ.dossier.en_construction?
            champ.code_departement = nil
            champ.code_postal = nil
            champ.external_id = nil
            champ.value = nil
            champ.save(validate: false)

            ask_user_correction(champ)
          end
        end
      end
    end

    def count
      # osf, count is not an option
    end

    private

    def ask_user_correction(champ)
      dossier = champ.dossier

      commentaire = CommentaireService.build(current_instructeur, dossier, { body: "Suite à un problème technique, Veuillez re-remplir le champs : #{champ.libelle}" })
      dossier.flag_as_pending_correction!(commentaire, :incomplete)
    end

    def current_instructeur
      user = User.find_by(email: DEFAULT_INSTRUCTEUR_EMAIL)
      user ||= User.create(email: DEFAULT_INSTRUCTEUR_EMAIL,
                           password: Random.srand,
                           confirmed_at: Time.zone.now,
                           email_verified_at: Time.zone.now)
      instructeur = user.instructeur
      instructeur ||= user.create_instructeur!

      instructeur
    end

    def fixable?(champ)
      champ.dossier.en_instruction? || champ.dossier.en_construction?
    end

    def notify(message, champ) = Sentry.capture_message(message, extra: { champ: })
  end
end
