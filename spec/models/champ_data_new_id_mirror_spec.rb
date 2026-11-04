# frozen_string_literal: true

describe ChampData do
  describe 'the champs.new_id mirror trigger' do
    let(:dossier) { dossiers.en_construction }

    # Asserted at the SQL level on purpose: the mirror is a database trigger, so
    # it must hold for every insert, including the ones that bypass the models
    # (backfills, maintenance tasks, raw COPY).
    it 'fills new_id with the id assigned on insert' do
      row = ActiveRecord::Base.connection.select_one(<<~SQL.squish)
        INSERT INTO champs (type, stream, private, stable_id, dossier_id, created_at, updated_at)
        VALUES ('Champs::TextChamp', #{ActiveRecord::Base.connection.quote(Dossier::MAIN_STREAM)},
                false, -1, #{dossier.id}, now(), now())
        RETURNING id, new_id
      SQL

      expect(row['new_id']).to eq(row['id'])
    end

    it 'fills new_id for champs created through the models' do
      champ = dossier.champs.first.dup
      champ.stable_id = -2
      champ.save!

      expect(champ.reload.new_id).to eq(champ.id)
    end

    it 'is installed by db:schema:load, which schema.rb cannot express' do
      trigger = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
        SELECT tgname FROM pg_trigger
        WHERE tgrelid = 'champs'::regclass AND NOT tgisinternal
      SQL

      expect(trigger).to eq('champs_mirror_new_id')
    end
  end
end
