# frozen_string_literal: true

class ExpertsProcedure < ApplicationRecord
  belongs_to :expert
  belongs_to :procedure

  has_many :avis, dependent: :destroy

  # Links that still open the dossier to their expert. An admin revocation only
  # bites while the procedure keeps a predefined list of experts: unchecking that
  # box puts the revocation to sleep, rechecking it wakes it up.
  #
  # The join carries Procedure's `kept` default scope, so a deleted procedure
  # drops its links too — a third criterion the scope's name does not say.
  scope :granting_access, -> {
    joins(:procedure)
      .where("experts_procedures.revoked_at IS NULL OR procedures.experts_require_administrateur_invitation IS NOT TRUE")
  }

  def revoked?
    revoked_at.present?
  end
end
