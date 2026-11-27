# frozen_string_literal: true

module ChampStreamConcern
  extend ActiveSupport::Concern

  def main_stream?
    stream == Dossier::MAIN_STREAM
  end

  def user_buffer_stream?
    stream == Dossier::USER_BUFFER_STREAM
  end

  def instructeur_buffer_stream?
    stream == Dossier::INSTRUCTEUR_BUFFER_STREAM
  end

  def history_stream?
    stream.start_with?(Dossier::HISTORY_STREAM)
  end

  def buffer_stream?
    persisted? && (user_buffer_stream? || instructeur_buffer_stream?)
  end

  # Whether this row held the champ's main stream value at `time`. A merge moves
  # the replaced row to "history:<time>" and records the same string as the
  # checkpoint of the row replacing it, so the two strings bound the period a
  # row spent on main. Rows without a checkpoint were written straight to main
  # (brouillon, rebase) or merged before the column existed (2026-06-02): their
  # creation dates their arrival, since a buffer row is created when the
  # correction starts. Timestamps are left out on purpose: fetches and machinery
  # keep stamping main rows after the deposit.
  def on_main_stream_at?(time)
    return false if !main_stream? && !history_stream?

    main_stream_since <= time && (main_stream_until.nil? || main_stream_until > time)
  end

  def main_stream_since
    checkpoint.present? ? Time.zone.parse(checkpoint.delete_prefix(Dossier::HISTORY_STREAM)) : created_at
  end

  def main_stream_until
    Time.zone.parse(stream.delete_prefix(Dossier::HISTORY_STREAM)) if history_stream?
  end

  def instructeur_buffer_source_stream?
    source_stream == Dossier::INSTRUCTEUR_BUFFER_STREAM
  end
end
