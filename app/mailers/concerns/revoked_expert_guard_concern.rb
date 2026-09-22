# frozen_string_literal: true

# An expert whose avis has been revoked by an instructeur, or whose whole link
# to the procedure has been revoked by an administrateur, has no access left to
# the dossier — so nothing about it may be mailed to them.
#
# The guard lives in the mailer rather than at each caller so that every path
# reaching a given mail is covered by one check, and so that the check runs at
# delivery time — a revocation landing between the enqueue and the delivery
# still stops the mail.
#
# It is opt-in per mailer, so a new mailer writing to an expert has to include
# this and call the guard. Making that impossible to forget would mean deriving
# the recipient here too, which needs the mailers to take keyword params first.
module RevokedExpertGuardConcern
  extend ActiveSupport::Concern

  private

  def not_revoked_avis(avis)
    avis = Array(avis)
    # An unsaved avis has no revocation to read, and treating it as revoked
    # would blank out the mailer previews, which build one entirely in memory.
    kept_ids = Avis.not_revoked.where(id: avis.filter(&:persisted?)).ids

    avis.filter { !it.persisted? || kept_ids.include?(it.id) }
  end
end
