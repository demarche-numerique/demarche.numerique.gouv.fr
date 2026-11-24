# frozen_string_literal: true

module APITokenTransferConcern
  extend ActiveSupport::Concern

  included do
    belongs_to :transfer_recipient, class_name: 'Administrateur', optional: true
  end

  def transferable? = authenticable? && !expired? && procedure_ids.any?

  def missing_procedure_ids_for(administrateur)
    procedure_ids - administrateur.procedure_ids_without_support
  end

  def transfer_eligible?(administrateur)
    administrateur.id != administrateur_id && missing_procedure_ids_for(administrateur).empty?
  end

  def transfer_coverage
    ids = procedure_ids
    counts = AdministrateursProcedure.without_support
      .where(procedure_id: ids)
      .where.not(administrateur_id:)
      .group(:administrateur_id)
      .count

    Administrateur.where(id: counts.keys)
      .map { [it, ids.size - counts[it.id]] }
      .sort_by { |administrateur, missing| [missing, administrateur.email] }
      .to_h
  end

  # Covers what the token may do: accepting one that changed since the
  # acceptance page was shown would hand over rights the recipient did not read.
  def transfer_fingerprint
    Digest::SHA256.hexdigest([
      procedure_ids.sort,
      full_access?,
      follows_clones?,
      write_access?,
      authorized_networks_for_ui,
      requires_ip_filtering?,
      expires_at,
    ].to_json)
  end

  def offer_transfer!(recipient, by:)
    with_lock do
      offered = administrateur_id == by.id && transferable? && transfer_eligible?(recipient)
      update!(transfer_recipient: recipient) if offered
      offered
    end
  end

  def cancel_transfer!(by:)
    with_lock do
      pending = administrateur_id == by.id && transfer_recipient_id.present?
      update!(transfer_recipient: nil) if pending
      pending
    end
  end

  def decline_transfer!(by:)
    with_lock do
      pending = transfer_recipient_id == by.id
      update!(transfer_recipient: nil) if pending
      pending
    end
  end

  def accept_transfer!(by:, fingerprint:)
    with_lock do
      outcome = transfer_outcome_for(by, fingerprint)

      if outcome == :accepted
        pin_procedures(procedure_ids)
        update!(administrateur: by, transfer_recipient: nil)
      end

      outcome
    end
  end

  private

  def transfer_outcome_for(recipient, fingerprint)
    if transfer_recipient_id != recipient.id || !transferable?
      :withdrawn
    elsif !transfer_eligible?(recipient)
      :ineligible
    elsif fingerprint != transfer_fingerprint
      :changed
    else
      :accepted
    end
  end
end
