# frozen_string_literal: true

class Champs::EngagementJuridiqueChamp < Champ
  # cf: https://communaute.chorus-pro.gouv.fr/documentation/creer-un-engagement/#1522314752186-a34f3662-0644b5d1-16c22add-8ea097de-3a0a
  validates_with ExpressionReguliereValidator,
                expression_reguliere: /([A-Z]|[0-9]|\-|\_|\+|\/)+/,
                expression_reguliere_error_message: "Le numéro d'EJ ne peut contenir que des caractères alphanumérique et les caractères spéciaux suivant : “-“ ; “_“ ; “+“ ; “/“",
                if: :validate_champ_value?
end
