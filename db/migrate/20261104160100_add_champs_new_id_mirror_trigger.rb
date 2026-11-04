# frozen_string_literal: true

# Second step of the champs.id int4 -> bigint migration: every new row gets its
# new_id from the start, so the backfill only ever has to catch up on history.
#
# BEFORE INSERT only: id is immutable, so covering UPDATE would be dead weight on
# the hottest table of the database.
#
# schema.rb cannot represent a trigger, so a database built by db:schema:load
# would not have it. lib/tasks/db_functions.rake recreates it from the constant
# below — the same mechanism already used for the french_unaccent text search
# configuration.
class AddChampsNewIdMirrorTrigger < ActiveRecord::Migration[8.1]
  # Not squished: Postgres stores the function source verbatim, and a one-line
  # plpgsql body makes pg_get_functiondef unreadable when debugging in production.
  CREATE_CHAMPS_NEW_ID_MIRROR_TRIGGER = <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs
    CREATE OR REPLACE FUNCTION champs_mirror_new_id() RETURNS trigger AS $$
    BEGIN
      NEW.new_id := NEW.id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS champs_mirror_new_id ON champs;

    CREATE TRIGGER champs_mirror_new_id
      BEFORE INSERT ON champs
      FOR EACH ROW EXECUTE FUNCTION champs_mirror_new_id();
  SQL

  DROP_CHAMPS_NEW_ID_MIRROR_TRIGGER = <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs
    DROP TRIGGER IF EXISTS champs_mirror_new_id ON champs;
    DROP FUNCTION IF EXISTS champs_mirror_new_id();
  SQL

  # Strong Migrations cannot analyse raw SQL, so it asks for an explicit
  # assertion. CREATE TRIGGER takes a SHARE ROW EXCLUSIVE lock on champs: it
  # blocks writes but not reads, and holds no scan, so it is a sub-second
  # operation. It can still queue behind a long-running transaction, which the
  # globally configured lock_timeout of 10 s bounds.
  def up
    safety_assured { execute CREATE_CHAMPS_NEW_ID_MIRROR_TRIGGER }
  end

  def down
    safety_assured { execute DROP_CHAMPS_NEW_ID_MIRROR_TRIGGER }
  end
end
