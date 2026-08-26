# frozen_string_literal: true

class TypesDeChamp::PrefillDossierLink < TypesDeChamp::Prefill
  private

  def screened_value(champ, value)
    # Base 10 so a leading zero is not parsed as octal; assign the parsed id
    # so the stored value is the one the screening ran against.
    dossier_id = Integer(value.to_s, 10, exception: false)
    return nil if dossier_id.nil?
    return nil if DossierLinkValidator.violations(dossier_id, self, user: champ.dossier.user).any?

    dossier_id.to_s
  end
end
