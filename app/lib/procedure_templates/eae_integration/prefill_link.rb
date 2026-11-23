# frozen_string_literal: true

module ProcedureTemplates
  class EaeIntegration
    # The link the school sends with the convocation: it opens the procedure
    # with what the school already knows about the applicant, who can still
    # correct it. A value the platform would refuse is an error here, where the
    # school can fix its list: the platform itself drops it without a word.
    #
    # Each visit of the link starts a new application: the convocation should
    # tell applicants to use it once, then to come back through their account.
    #
    # The name is optional, and travels in the link when given.
    #
    # For a whole intake, from a console:
    #   puts ProcedureTemplates::EaeIntegration::PrefillLink.csv(procedure, File.read("candidats.csv"))
    class PrefillLink
      FIELDS = [:recruitment, :entrance_exam, :corps].freeze
      CSV_HEADERS = { "nom" => :last_name, "prenom" => :first_name, "recrutement" => :recruitment, "concours" => :entrance_exam, "corps" => :corps }.freeze
      CSV_LINK_HEADER = "lien"

      def self.url(procedure, **applicant) = new(procedure).url(**applicant)

      # Takes the list of the school, one applicant per line under the headers
      # of CSV_HEADERS, and returns it with one more column, the link.
      def self.csv(procedure, list)
        prefill_link = new(procedure)
        col_sep = list.lines.first.to_s.count(";") > list.lines.first.to_s.count(",") ? ";" : ","
        rows = CSV.parse(list, headers: true, col_sep:, strip: true)
        unknown_headers = rows.headers - CSV_HEADERS.keys
        raise ArgumentError, "unknown columns: #{unknown_headers.join(', ')}" if unknown_headers.any?

        CSV.generate(col_sep:) do |csv|
          csv << rows.headers + [CSV_LINK_HEADER]
          rows.each.with_index(2) do |row, line|
            csv << row.fields + [prefill_link.url(**row.to_h.transform_keys(CSV_HEADERS))]
          rescue ArgumentError => e
            raise ArgumentError, "line #{line}: #{e.message}"
          end
        end
      end

      # The link only lasts once the procedure is published: publishing gives
      # the procedure its address, and the former one drops the prefill.
      def initialize(procedure)
        raise ArgumentError, "the procedure must be published" if !procedure.publiee?

        @procedure = procedure
        @revision = procedure.published_revision
      end

      def url(last_name: nil, first_name: nil, **values)
        identity = { "identite_nom" => last_name, "identite_prenom" => first_name }.compact_blank

        Rails.application.routes.url_helpers.commencer_url(path: @procedure.path, **identity, **field_params(values))
      end

      private

      def field_params(values)
        values.compact_blank.to_h do |key, value|
          type_de_champ = type_de_champ(key)
          if TypesDeChamp::PrefillTypeDeChamp.build(type_de_champ, @revision).to_assignable_attributes(nil, value).blank?
            raise ArgumentError, "#{type_de_champ.libelle}: #{value.inspect} is not one of #{type_de_champ.drop_down_options.to_sentence}"
          end

          ["champ_#{type_de_champ.to_typed_id_for_query}", value]
        end
      end

      # Found by its label: the builder does not keep the ids it creates.
      def type_de_champ(key)
        raise ArgumentError, "#{key} is not prefilled by the link" if !key.in?(FIELDS)

        libelle = PUBLIC_FIELDS.find { it[:key] == key }.fetch(:libelle)
        @revision.public_root_type_de_champs.find { it.libelle == libelle } ||
          raise(ArgumentError, "no field « #{libelle} » in the procedure")
      end
    end
  end
end
