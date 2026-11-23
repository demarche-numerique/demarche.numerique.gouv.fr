# frozen_string_literal: true

# Log of every administrateur account creation from the manager. Up to
# MAX_EMAILS_WITHOUT_VALIDATION addresses, the request is approved on the spot;
# above, another super admin approves it within VALIDITY.
class AdministrateurCreationRequest < ApplicationRecord
  MAX_EMAILS = 100
  MAX_EMAILS_WITHOUT_VALIDATION = 10
  DAILY_QUOTA = 300
  VALIDITY = 24.hours
  # Anything around an address in a pasted mail header: separators, names, chevrons, quotes.
  EMAIL_REGEXP = /[^[:space:]<>,;:"'()\[\]]+@[^[:space:]<>,;:"'()\[\]]+/

  # Optional: the log outlives a deleted super admin.
  belongs_to :requester, class_name: 'SuperAdmin', optional: true
  belongs_to :validator, class_name: 'SuperAdmin', optional: true

  enum :state, { pending: 'pending', approved: 'approved', refused: 'refused', cancelled: 'cancelled' }

  validates :requester, presence: true, on: :create
  validates :emails, length: { in: 1..MAX_EMAILS }
  validate :daily_quota, on: :create

  def self.parse_emails(text) = text.to_s.scan(EMAIL_REGEXP).map { it.downcase.delete_suffix('.') }.uniq

  def requires_validation? = emails.size > MAX_EMAILS_WITHOUT_VALIDATION

  def expires_at = created_at + VALIDITY

  def expired? = pending? && expires_at.past?

  def open? = pending? && !expired?

  def status = expired? ? 'expired' : state

  def domains = emails.map { it.split('@').last }.tally.sort_by { -it.last }

  def approve!(validator) = decide!(:approved, validator)

  def refuse!(validator) = decide!(:refused, validator)

  def cancel! = decide!(:cancelled, nil)

  def create_accounts!
    inviter = validator || requester
    pending_emails = emails - results.keys
    existing = User.joins(:administrateur).where(email: pending_emails).pluck(:email)

    # Saved one by one, so that a retry after a crash keeps what is already done.
    pending_emails.each do |email|
      outcome = if email.in?(existing)
        'already_administrateur'
      else
        inviter.invite_admin(email).errors.empty? ? 'created' : 'invalid'
      end
      update!(results: results.merge(email => outcome))
    end
  end

  def results_summary
    created, ignored, invalid = results.keys.group_by { results[it] }.values_at('created', 'already_administrateur', 'invalid')

    [
      (I18n.t('manager.administrateur_creation_requests.results.created', count: created.size) if created),
      (I18n.t('manager.administrateur_creation_requests.results.already_administrateur', count: ignored.size, emails: ignored.join(', ')) if ignored),
      (I18n.t('manager.administrateur_creation_requests.results.invalid', count: invalid.size, emails: invalid.join(', ')) if invalid),
    ].compact.join(' ')
  end

  private

  def decide!(state, validator)
    with_lock do
      next false if !open?

      update!(state:, validator:, decided_at: Time.current)
    end
  end

  def daily_quota
    already_requested = self.class
      .where(requester_id:, state: [:pending, :approved], created_at: 24.hours.ago..)
      .sum('cardinality(emails)')

    errors.add(:emails, :daily_quota_exceeded, count: DAILY_QUOTA) if already_requested + emails.size > DAILY_QUOTA
  end
end
