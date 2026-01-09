# frozen_string_literal: true

module Maintenance
  class CopySuperAdminOtpSecretToRails7EncryptedAttrTask < MaintenanceTasks::Task
    # Cette tâche finalise la mise à niveau vers devies-two-factor 5
    # qui utilise les encrypted attributes de Rails 7.
    # Elle copie les secrets OTP des super admins vers la nouvelle colonne
    # avant une suppression plus tard des anciennes colonnes.
    # Plus d’informations : https://github.com/devise-two-factor/devise-two-factor/blob/main/UPGRADING.md
    # Introduit 2024-08-29, https://github.com/demarches-simplifiees/demarches-simplifiees.fr/pull/10722
    def collection
      SuperAdmin.all
    end

    def process(super_admin)
      # From https://github.com/devise-two-factor/devise-two-factor/blob/main/UPGRADING.md
      otp_secret = super_admin.otp_secret # read from otp_secret column, fall back to legacy columns if new column is empty
      # This is NOOP when otp_secret column has already the same value
      super_admin.update!(otp_secret: otp_secret)
    end

    def count
      SuperAdmin.count
    end
  end
end
