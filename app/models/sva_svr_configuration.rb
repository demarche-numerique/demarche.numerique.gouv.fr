# frozen_string_literal: true

class SVASVRConfiguration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :decision, default: 'disabled'
  attribute :period, default: 2
  attribute :unit, default: 'months'
  attribute :resume, default: 'continue'

  DECISION_OPTIONS = ['disabled', 'sva', 'svr']
  UNIT_OPTIONS = ['days', 'weeks', 'months']
  RESUME_OPTIONS = ['continue', 'reset']

  validates :decision, inclusion: { in: DECISION_OPTIONS }
  validates :period, presence: true, numericality: { only_integer: true }, if: -> { enabled? }
  validates :unit, presence: true, inclusion: { in: UNIT_OPTIONS }, if: -> { enabled? }
  validates :resume, presence: true, inclusion: { in: RESUME_OPTIONS }, if: -> { enabled? }

  def self.unit_options
    UNIT_OPTIONS
  end

  def human_decision
    return if decision == 'disabled'

    decision.upcase
  end

  def human_delay
    I18n.t("x_#{unit}", count: period.to_i, scope: 'datetime.distance_in_words')
  end

  private

  def enabled?
    decision != 'disabled'
  end
end
