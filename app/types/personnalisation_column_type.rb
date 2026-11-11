# frozen_string_literal: true

# The rescue must not live in ColumnType: ProcedurePresentation relies on
# the raise to reject unresolvable columns through validates_associated.
class PersonnalisationColumnType < ColumnType
  def deserialize(value)
    super.then { it.try(:applicant_column) || it }
  rescue ActiveRecord::RecordNotFound => e
    Sentry.capture_exception(e)
    nil
  end
end
