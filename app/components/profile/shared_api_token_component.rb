# frozen_string_literal: true

class Profile::SharedAPITokenComponent < Profile::APITokenComponent
  def initialize(api_token:, reader_procedure_ids:)
    super(api_token:)
    @reader_procedure_ids = reader_procedure_ids
  end

  private

  def row_id = dom_id(@api_token, :shared)

  def name_id = dom_id(@api_token, :shared_name)

  def subtitle = t('.managed_by', email: owner_email)

  def procedures
    listed = listed_procedures { t('.shared_procedures_count', count: it) }
    others = procedure_ids.size - shared_procedure_ids.size

    if @api_token.full_access?
      t('.all_procedures_html', email: owner_email, procedures: listed)
    elsif others.positive?
      with_clones(t('.with_others_html', procedures: listed, count: others, email: owner_email))
    else
      with_clones(listed)
    end
  end

  def shared_procedure_ids = @shared_procedure_ids ||= procedure_ids.intersection(@reader_procedure_ids)

  def named_procedure_ids = shared_procedure_ids

  def actions = []

  def owner_email = @api_token.administrateur.email
end
