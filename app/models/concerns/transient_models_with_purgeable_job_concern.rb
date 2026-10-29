# frozen_string_literal: true

# Archive and Export models are generated in background
#   those models being are destroy after an expiration period
#   but, it might take more time to process than the expiration period
#   this module expose the shared behaviour to compute a job and purge instances
#   based on a state machine
module TransientModelsWithPurgeableJobConcern
  extend ActiveSupport::Concern

  included do
    include AASM

    enum :job_status, {
      pending: 'pending',
      generated: 'generated',
      failed: 'failed',
      too_large: 'too_large',
    }

    aasm whiny_persistence: true, column: :job_status, enum: true do
      state :pending, initial: true
      state :generated
      state :failed
      state :too_large

      event :make_available do
        transitions from: :pending, to: :generated
      end
      event :restart do
        transitions from: :failed, to: :pending
      end
      event :fail do
        transitions from: :pending, to: :failed
      end
      event :mark_too_large do
        transitions from: :pending, to: :too_large
      end
    end

    scope :stale, lambda { |duration|
      where(job_status: job_statuses.values_at(:generated, :failed, :too_large))
        .where(updated_at: ...(Time.zone.now - duration))
    }

    scope :stuck, lambda { |duration|
      where(job_status: [job_statuses.fetch(:pending)])
        .where(updated_at: ...(Time.zone.now - duration))
    }
  end

  def available?
    generated? && file.url.present?
  end

  def compute_with_safe_stale_for_purge(&block)
    return if generated? || too_large? # idempotent on retry after success
    restart! if failed? # restart for AASM
    yield
    make_available! if pending?
  rescue => e
    fail!         # fail for observability
    raise e       # re-raise for retryable behaviour
  end
end
