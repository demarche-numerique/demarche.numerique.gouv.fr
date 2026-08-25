# frozen_string_literal: true

# The model no longer reads nor writes type_champ, but the development
# database is shared with workspaces still running the old code. A trigger
# keeps both discriminators aligned (old code writes type_champ, new code
# writes type, nobody breaks) — the same shape a production rollout
# transition needs. Dropping the column is the final step once no old code
# remains.
#
# The trigger does not appear in schema.rb (plain ruby format): it only
# lives in databases where this migration ran.
class SyncTypeChampWithType < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        CREATE OR REPLACE FUNCTION sync_types_de_champ_discriminators() RETURNS trigger AS $sync$
        BEGIN
          IF TG_OP = 'INSERT' THEN
            IF NEW.type IS NULL AND NEW.type_champ IS NOT NULL THEN
              NEW.type := #{vocab_to_class_sql};
            ELSIF NEW.type IS NOT NULL THEN
              NEW.type_champ := #{class_to_vocab_sql};
            END IF;
          ELSE
            IF NEW.type IS DISTINCT FROM OLD.type THEN
              NEW.type_champ := #{class_to_vocab_sql};
            ELSIF NEW.type_champ IS DISTINCT FROM OLD.type_champ THEN
              NEW.type := #{vocab_to_class_sql};
            END IF;
          END IF;
          RETURN NEW;
        END
        $sync$ LANGUAGE plpgsql;
      SQL

      execute(<<~SQL.squish)
        CREATE TRIGGER sync_types_de_champ_discriminators
        BEFORE INSERT OR UPDATE ON types_de_champ
        FOR EACH ROW EXECUTE FUNCTION sync_types_de_champ_discriminators()
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER IF EXISTS sync_types_de_champ_discriminators ON types_de_champ")
      execute("DROP FUNCTION IF EXISTS sync_types_de_champ_discriminators()")
    end
  end

  private

  # ELSE keeps the current value: an unknown name (a legacy type, a value the
  # mapping does not know yet) must never null the other column.
  def vocab_to_class_sql
    cases = TypeDeChamp::CLASS_NAME_TO_TYPE_CHAMP.map { |klass, vocab| "WHEN '#{vocab}' THEN '#{klass}'" }.join(' ')
    "CASE NEW.type_champ #{cases} ELSE NEW.type END"
  end

  def class_to_vocab_sql
    cases = TypeDeChamp::CLASS_NAME_TO_TYPE_CHAMP.map { |klass, vocab| "WHEN '#{klass}' THEN '#{vocab}'" }.join(' ')
    "CASE NEW.type #{cases} ELSE NEW.type_champ END"
  end
end
