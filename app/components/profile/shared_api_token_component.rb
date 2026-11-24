# frozen_string_literal: true

class Profile::SharedAPITokenComponent < Profile::APITokenComponent
  def initialize(api_token:, reader_procedure_ids:)
    super(api_token:)
    @reader_procedure_ids = reader_procedure_ids
  end

  private

  def subtitle = t('.managed_by', email: owner_email)

  def procedures_count = t('.shared_procedures_count', count: named_procedure_ids.size)

  def procedures_note
    others = procedure_ids.size - named_procedure_ids.size
    owner_procedures = if @api_token.full_access?
      t('.among_all', email: owner_email)
    elsif others.positive?
      t('.others', count: others, email: owner_email)
    end

    safe_join([owner_procedures, clones].compact, ' ').presence
  end

  def named_procedure_ids = @named_procedure_ids ||= procedure_ids.intersection(@reader_procedure_ids)

  def actions = [duplicate_button]

  def label_args = { name: @api_token.name, email: owner_email }

  def owner_email = @api_token.administrateur.email
end
