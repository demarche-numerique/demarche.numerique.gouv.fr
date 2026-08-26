# frozen_string_literal: true

class TypesDeChamp::Phone < TypesDeChamp::Text
  def self.category = ETAT_CIVIL

  # We want to allow:
  # * international (e164) phone numbers
  # * “french format” (ten digits with a leading 0)
  # * DROM numbers
  #
  # However, we need to special-case some ten-digit numbers,
  # because the ARCEP assigns some blocks of "O6 XX XX XX XX" numbers to DROM operators.
  # Guadeloupe          | GP | +590 | 0690XXXXXX, 0691XXXXXX
  # Guyane              | GF | +594 | 0694XXXXXX
  # Martinique          | MQ | +596 | 0696XXXXXX, 0697XXXXXX
  # Réunion             | RE | +262 | 0692XXXXXX, 0693XXXXXX
  # Mayotte             | YT | +262 | 0692XXXXXX, 0693XXXXXX
  # Nouvelle-Calédonie  | NC | +687 |
  # Polynésie française | PF | +689 | 40XXXXXX, 45XXXXXX, 87XXXXXX, 88XXXXXX, 89XXXXXX
  #
  # Cf: Plan national de numérotation téléphonique,
  # https://www.arcep.fr/uploads/tx_gsavis/05-1085.pdf  “Numéros mobiles à 10 chiffres”, page 6
  #
  # See issue #6996.
  DEFAULT_COUNTRY_CODES = [:FR, :GP, :GF, :MQ, :RE, :YT, :NC, :PF].freeze

  def typed_champ_value(champ)
    if Phonelib.valid_for_countries?(champ.value, DEFAULT_COUNTRY_CODES)
      Phonelib.parse_for_countries(champ.value, DEFAULT_COUNTRY_CODES).full_national
    else
      # When he phone number is possible for the default countries, but not strictly valid,
      # `full_national` could mess up the formatting. In this case just return the original.
      champ.value
    end
  end
end
