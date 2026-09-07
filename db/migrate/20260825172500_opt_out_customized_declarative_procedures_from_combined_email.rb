# frozen_string_literal: true

# A declarative procedure whose admin already customized an email template stays
# on the legacy two emails: switching it would silently replace a text they
# wrote. In a migration rather than in a maintenance task, to land before the
# code that reads the flag.
class OptOutCustomizedDeclarativeProceduresFromCombinedEmail < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE procedures
        SET combined_declarative_email = false
        WHERE declarative_with_state IS NOT NULL
          AND id IN (SELECT procedure_id FROM email_templates)
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
