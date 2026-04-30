# frozen_string_literal: true

module Maintenance
  class T20260408BackfillReferentielTiptapColumnsTask < MaintenanceTasks::Task
    def collection
      Referentiels::APIReferentiel.where(use_tiptap: false)
    end

    def process(referentiel)
      if referentiel.url.present?
        referentiel.update_columns(
          url_tiptap: convert_url_to_tiptap(referentiel.url),
          test_data_tiptap: convert_test_data_to_tiptap(referentiel.test_data)
        )
      end

      activate(referentiel)
    end

    def count
      collection.count
    end

    private

    def activate(referentiel)
      return referentiel.update_column(:use_tiptap, true) if skip_api_verification?(referentiel)

      verify_and_activate(referentiel)
    end

    def skip_api_verification?(referentiel)
      referentiel.url_tiptap.blank? || referentiel.last_response.blank?
    end

    def verify_and_activate(referentiel)
      baseline_status = referentiel.last_response_status

      # Temporarily enable tiptap in memory to test the new URL resolution path
      referentiel.use_tiptap = true
      service = ReferentielService.new(referentiel:)
      resolved = service.test_url

      if resolved.nil?
        Sentry.capture_message("BackfillReferentielTiptap: could not resolve tiptap URL", extra: { referentiel_id: referentiel.id })
        return
      end

      result = API::Client.new.call(
        url: resolved,
        timeout: ReferentielService::API_TIMEOUT,
        headers: service.send(:headers),
        maxfilesize: ReferentielService::MAX_FILE_SIZE
      )

      response_status = result.success? ? 200 : result.failure[:code]

      if response_status == baseline_status
        referentiel.update_column(:use_tiptap, true)
      else
        Sentry.capture_message(
          "BackfillReferentielTiptap: status mismatch",
          extra: { referentiel_id: referentiel.id, baseline: baseline_status, got: response_status }
        )
      end
    end

    def convert_url_to_tiptap(url_string)
      parts = url_string.split('{id}', -1)

      content = []
      parts.each_with_index do |part, i|
        content << { type: "text", text: part } if part.present?
        if i < parts.length - 1
          content << {
            type: "mention",
            attrs: { id: "{query}", label: "Valeur saisie par l'usager" },
          }
        end
      end

      { type: "doc", content: [{ type: "paragraph", content: }] }
    end

    def convert_test_data_to_tiptap(test_data)
      return nil if test_data.blank?
      { "{query}" => test_data }
    end
  end
end
