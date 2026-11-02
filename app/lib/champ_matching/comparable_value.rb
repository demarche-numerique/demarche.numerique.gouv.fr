# frozen_string_literal: true

module ChampMatching
  module ComparableValue
    COMPARISON_NAMESPACES = {
      'text' => :text, 'textarea' => :text, 'formatted' => :text,
      'email' => :email,
      'phone' => :phone,
      'iban' => :iban,
      'siret' => :siret, 'rna' => :rna, 'rnf' => :rnf,
      'communes' => :communes, 'epci' => :epci, 'annuaire_education' => :annuaire_education,
      'address' => :address,
      'date' => :date, 'datetime' => :date,
    }.freeze

    TYPE_CHAMPS = COMPARISON_NAMESPACES.keys.freeze

    CHAMP_TYPES = COMPARISON_NAMESPACES
      .transform_keys { TypeDeChamp.type_champ_to_champ_class_name(it) }
      .freeze

    MIN_LENGTH = 3

    STOP_VALUES = ['oui', 'non', 'na', 'nc', 'neant', 'aucun', 'aucune', 'sans objet'].freeze

    class << self
      def call(namespace:, value: nil, value_json: nil, external_id: nil)
        case namespace
        when :address then address_value(value_json)
        when :date then value.presence && value.to_s.first(10)
        when :email then value.presence && value.strip.downcase
        when :phone then phone_value(value)
        when :iban then iban_value(value)
        when :text then free_text_value(value)
        when :siret, :rna, :rnf, :communes, :epci, :annuaire_education then external_id.presence && external_id.strip.downcase
        end
      end

      private

      def address_value(value_json)
        return if value_json.blank?

        codes = value_json.values_at('postal_code', 'city_code').compact_blank
        return if codes.empty?

        (codes + [normalize(value_json['street_address'])]).compact_blank.join('|')
      end

      def phone_value(value)
        digits = value.to_s.gsub(/\D/, '').sub(/\A(?:0033|33)/, '0')

        digits if digits.size >= 9
      end

      def iban_value(value)
        alphanumeric = value.to_s.gsub(/[^A-Za-z0-9]/, '').upcase

        alphanumeric if alphanumeric.size >= 14
      end

      def free_text_value(value)
        normalized = normalize(value)
        return if normalized.blank? || normalized.size < MIN_LENGTH || normalized.in?(STOP_VALUES)

        normalized
      end

      def normalize(value)
        I18n.transliterate(value.to_s).downcase.gsub(/[[:punct:]]/, ' ').squish
      end
    end
  end
end
