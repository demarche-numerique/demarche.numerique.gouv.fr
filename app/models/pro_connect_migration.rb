# frozen_string_literal: true

class ProConnectMigration < ApplicationRecord
  PENDING_FOR = 30.minutes
  SUPPORT_STATES = ['domain_mismatch', 'existing_account'].freeze
  CODE_VALIDITY = 10.minutes
  MAX_CODE_ATTEMPTS = 5
  RESEND_AFTER = 1.minute
  # Measured on the .gouv.fr addresses of the service-public directory. A nominative address
  # caught here only costs its owner typing it on the ProConnect email page.
  FUNCTIONAL_MAILBOX_PREFIXES = [
    'service', 'contact', 'accueil', 'secretariat', 'secretaire', 'communication', 'courrier', 'direct', 'prefecture',
    'souspref', 'sousdir', 'admin', 'info', 'webmaster', 'webmestre', 'noreply', 'postmaster', 'association', 'archive',
    'mission', 'consulat', 'ambafrance', 'chancellerie', 'commissariat', 'police', 'academie', 'rectorat', 'conciliateur',
    'codefi', 'droitsdesfemmes', 'guichet', 'cabinet', 'support', 'assistance', 'gestion', 'plateforme', 'cellule',
  ].freeze
  # Acronyms of services and words close to a surname: only as a whole word, so that cedric.martin keeps the hint.
  FUNCTIONAL_MAILBOX_WORD = /\A(?:ce|sgc|sgar|sgae|sg|sp|pref|ddt|ddtm|ddets|ddetspp|ddcs|ddcspp|ddpp|ddfip|drfip|dfip|ddsp|dreal|dreets|deets|draaf|daaf|drac|deal|ars|dsden|udap|sdap|spfe|spf|sdif|sie|sip|sde|cad|dgs|dgas|dga|dgt|dgos|dg|drh|rh|dsi|dsn|dnum|dircofi|dir|dmd|ud|ggd|dares|drari|prs|sec|com|bureau|pole|bal|demarches?|demat|dematerialisation|teleservices?|t\d+)(?![a-z])/

  belongs_to :user
  belongs_to :target_user, class_name: 'User', optional: true
  belongs_to :parent, class_name: 'ProConnectMigration', optional: true
  has_many :children, class_name: 'ProConnectMigration', foreign_key: :parent_id, inverse_of: :parent, dependent: nil

  enum :state, {
    started: 'started',
    same_email: 'same_email',
    domain_mismatch: 'domain_mismatch',
    existing_account: 'existing_account',
    awaiting_code: 'awaiting_code',
    renamed: 'renamed',
    granted: 'granted',
  }

  scope :pending, -> { started.where(created_at: PENDING_FOR.ago..) }
  scope :sent_to_support, -> { where(state: SUPPORT_STATES, updated_at: PENDING_FOR.ago..) }
  scope :waiting_for_code, -> { awaiting_code.where(updated_at: PENDING_FOR.ago..) }
  scope :completed, -> { where(state: [:renamed, :granted]) }
  scope :joinable, -> { renamed.where(shared: true) }
  scope :shown_on_account, -> (user) { completed.where(target_user: user).or(renamed.where(source_email: user.email)) }

  def self.joinable_for(email) = joinable.where(source_email: email).last

  # Only an account ProConnect binds, while the migration is open to it:
  # sessions#create then signs it out at once.
  def self.renamed_account_for(email)
    account = joinable_for(email)&.user
    account if account&.administrateur&.pro_connect_required? && Flipper.enabled?(:administrateur_pro_connect_migration, account)
  end

  # ProConnect skips its email page when given a hint, and sends the agent straight to the
  # provider of the domain under that address: a shared mailbox is not theirs to use.
  def login_hint
    source_email if !functional_mailbox?
  end

  def identify!(auth:)
    update!(pro_connect_email: auth.email, state: outcome_for(auth.email))
  end

  def sent_to_support? = state.in?(SUPPORT_STATES)

  def send_code!(browser)
    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, '0')
    # Leaves updated_at at the ProConnect return, which bounds waiting_for_code.
    update_columns(code_digest: digest(code), code_sent_at: Time.current)
    UserMailer.pro_connect_migration_code(self, code, browser_description(browser)).deliver_later
  end

  # Counted in one statement: two requests in flight cannot both pass the last attempt.
  def verify_code(code)
    counted = self.class.awaiting_code
      .where(id:, code_sent_at: CODE_VALIDITY.ago.., code_attempts: ...MAX_CODE_ATTEMPTS)
      .update_counters(code_attempts: 1) == 1

    counted && ActiveSupport::SecurityUtils.secure_compare(code_digest, digest(code.to_s.gsub(/\s/, '')))
  end

  def resend_code!(browser)
    claimed = self.class.awaiting_code.where(id:, code_sent_at: ..RESEND_AFTER.ago).update_all(code_sent_at: Time.current) == 1
    send_code!(browser) if claimed
    claimed
  end

  def code_expired? = code_sent_at <= CODE_VALIDITY.ago

  def attempts_spent? = code_attempts >= MAX_CODE_ATTEMPTS

  def rename!(auth:, shared:)
    transaction do
      # Without the default eager_load: PostgreSQL refuses FOR UPDATE on an outer join.
      account = User.unscope(:eager_load).lock.find(user_id)
      next false if account.email != source_email || auth.email != pro_connect_email || User.exists?(email: pro_connect_email)

      update!(
        state: :renamed, target_user: account, shared:,
        procedure_ids: owned_procedure_ids(account), groupe_instructeur_ids: assigned_groupe_instructeur_ids(account)
      )
      account.skip_reconfirmation!
      account.update!(email: pro_connect_email, email_verified_at: Time.current, unconfirmed_email: nil, requested_merge_into: nil)
      account.administrateur.update!(pro_connect_required_at: Time.current)
      ProConnectInformation.record!(user: account, auth:)
      true
    end
  end

  def grant!(auth:)
    transaction do
      next false if auth.email != pro_connect_email

      target = User.find_or_create_for_pro_connect!(pro_connect_email)
      target.create_instructeur! if target.instructeur.nil?
      target.become_administrateur! if target.administrateur.nil?
      administrateur = target.administrateur
      administrateur.update!(pro_connect_required_at: Time.current) if !administrateur.pro_connect_required_at?

      Procedure.with_discarded.where(id: parent.procedure_ids).find_each do |procedure|
        AdministrateursProcedure.create_or_find_by!(administrateur:, procedure:)
      end
      GroupeInstructeur.where(id: parent.groupe_instructeur_ids).find_each { it.add(target.instructeur) }

      ProConnectInformation.record!(user: target, auth:)
      update!(state: :granted, target_user: target)
      true
    end
  end

  # The account of a co-holder who kept the old address on ProConnect, or an unrelated one.
  # Either way User.find_for_database_authentication now finds it instead of the renamed account.
  def address_taken_by
    User.find_by(email: source_email) if renamed?
  end

  def granted_to?(user) = children.granted.exists?(target_user: user)

  private

  def functional_mailbox?
    local_part = source_email.split('@').first
    local_part.delete('._-').start_with?(*FUNCTIONAL_MAILBOX_PREFIXES) || local_part.match?(FUNCTIONAL_MAILBOX_WORD)
  end

  def outcome_for(email)
    if domain(email) != domain(source_email)
      :domain_mismatch
    elsif parent
      :awaiting_code
    elsif email == source_email
      :same_email
    elsif User.exists?(email:)
      :existing_account
    else
      :awaiting_code
    end
  end

  def domain(email) = email.split('@').last

  def digest(code)
    key = Rails.application.key_generator.generate_key('pro_connect_migration_code')
    OpenSSL::HMAC.hexdigest('SHA256', key, "#{id}:#{code}")
  end

  def browser_description(browser)
    "#{browser.name} #{browser.full_version} (#{browser.platform.name})" if browser.known?
  end

  # The manager rows are the support accesses of super admins.
  def owned_procedure_ids(account)
    account.administrateur.administrateurs_procedures.where(manager: [false, nil]).pluck(:procedure_id)
  end

  def assigned_groupe_instructeur_ids(account)
    AssignTo.where(instructeur: account.instructeur, manager: [false, nil]).pluck(:groupe_instructeur_id)
  end
end
