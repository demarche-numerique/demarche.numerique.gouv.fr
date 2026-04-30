# frozen_string_literal: true

class Rdv < ApplicationRecord
  belongs_to :dossier
  belongs_to :instructeur

  validates :rdv_plan_external_id, presence: true, format: { with: /\A\d+\z/ }
  validates :rdv_external_id, format: { with: /\A\d+\z/ }, allow_nil: true
  validates :starts_at, presence: true, if: -> { rdv_external_id.present? }

  scope :booked, -> { where.not(rdv_external_id: nil) }
  scope :pending, -> { where(rdv_external_id: nil) }
  scope :upcoming, -> { where("starts_at > ?", Time.zone.now) }
  scope :by_starts_at, -> { order(starts_at: :asc) }

  def rdv_plan_url
    "#{ENV["RDV_SERVICE_PUBLIC_URL"]}/agents/rdv_plans/#{rdv_plan_external_id}"
  end

  def upcoming?
    starts_at > Time.zone.now
  end
end
