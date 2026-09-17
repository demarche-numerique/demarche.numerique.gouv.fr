# frozen_string_literal: true

# `champs.id` is a `serial` (int4). These read-only tasks report how much of the
# 2 147 483 647 ceiling is left and how fast it is being consumed, so the bigint
# migration can be scheduled on measurements rather than on intuition.
#
# Both tasks only read the catalog and the statistics views: they never scan
# `champs`, which is the largest table of the database.
namespace :champs do
  INT4_CEILING = 2_147_483_647

  desc <<~EOD
    Report the remaining headroom on champs.id and the observed consumption rate.

    bin/rails champs:id_headroom
  EOD
  task id_headroom: :environment do
    conn = ActiveRecord::Base.connection

    sequence = conn.select_value("SELECT pg_get_serial_sequence('champs', 'id')")
    column_type = conn.select_value(<<~SQL.squish)
      SELECT format_type(atttypid, atttypmod)
      FROM pg_attribute
      WHERE attrelid = 'champs'::regclass AND attname = 'id'
    SQL

    sequence_info = conn.select_one(<<~SQL.squish)
      SELECT data_type::text, max_value, last_value
      FROM pg_sequences
      WHERE schemaname || '.' || sequencename = #{conn.quote(sequence)}
    SQL

    # `stats_reset` lives in pg_stat_database, not in pg_stat_user_tables.
    stats = conn.select_one(<<~SQL.squish)
      SELECT t.n_tup_ins, t.n_tup_del, d.stats_reset,
             EXTRACT(EPOCH FROM now() - d.stats_reset) AS elapsed
      FROM pg_stat_user_tables t
      CROSS JOIN pg_stat_database d
      WHERE t.relname = 'champs' AND d.datname = current_database()
    SQL

    ceiling = column_type == 'integer' ? INT4_CEILING : sequence_info['max_value'].to_i
    last_value = sequence_info['last_value'].to_i
    headroom = ceiling - last_value
    elapsed = stats['elapsed'].to_f

    puts "column    : champs.id is #{column_type}"
    puts "sequence  : #{sequence} is #{sequence_info['data_type']}, max_value #{delimited(sequence_info['max_value'])}"

    # The column type and the sequence type are two independent ceilings, and a
    # dump/restore cycle can leave them out of sync. A bigint sequence feeding an
    # int4 column is a latent failure: nextval eventually returns a value the
    # column rejects, and every insert fails from then on.
    if column_type == 'integer' && sequence_info['data_type'] != 'integer'
      puts "WARNING   : the sequence is #{sequence_info['data_type']} but the column is integer —"
      puts "            nextval can return a value the column refuses. The column is the binding ceiling."
    end
    puts "position  : #{delimited(last_value)} (#{(100.0 * last_value / ceiling).round(2)} % of the ceiling)"
    puts "headroom  : #{delimited(headroom)} ids"

    if elapsed.positive?
      per_day = stats['n_tup_ins'].to_i * 86_400 / elapsed
      puts "inserts   : #{delimited(stats['n_tup_ins'])} since #{stats['stats_reset']} (#{(elapsed / 86_400).round(1)} days)"
      puts "rate      : ~#{delimited(per_day.round)} ids/day (floor: rolled back inserts also burn ids)"
      puts "exhausted : in #{delimited((headroom / per_day).round)} days, around #{Date.current + (headroom / per_day).round}" if per_day.positive?
    else
      puts "rate      : not datable, pg_stat_database.stats_reset is NULL — use champs:id_curve"
    end
  end

  desc <<~EOD
    Reconstruct the id consumption curve by sampling the primary key: `created_at`
    at id X dates the moment X was issued. Robust to deleted rows — the surviving
    row closest below X still dates X.

    bin/rails champs:id_curve         # 10M steps over the whole history
    STEP=1000000 bin/rails champs:id_curve
  EOD
  task id_curve: :environment do
    step = Integer(ENV.fetch('STEP', 10_000_000))
    conn = ActiveRecord::Base.connection
    max_id = conn.select_value("SELECT max(id) FROM champs").to_i
    abort 'champs is empty' if max_id.zero?

    samples = []
    id = max_id
    while id.positive?
      # The window bounds the backwards scan to a single step.
      row = conn.select_one(<<~SQL.squish)
        SELECT id, created_at FROM champs
        WHERE id <= #{id} AND id > #{id - step} AND created_at IS NOT NULL
        ORDER BY id DESC LIMIT 1
      SQL
      samples << [row['id'].to_i, row['created_at'].to_time] if row
      id -= step
    end
    abort 'less than 2 usable samples — lower STEP' if samples.size < 2

    puts "max(id) #{delimited(max_id)} · headroom #{delimited(INT4_CEILING - max_id)} · #{samples.size} samples of #{delimited(step)}"
    puts
    puts format('%-18s %-12s %14s %10s %14s', 'id', 'date', 'ids', 'days', 'ids/day')
    puts '-' * 72

    rates = []
    samples.each_cons(2) do |(id_hi, at_hi), (id_lo, at_lo)|
      days = (at_hi - at_lo) / 86_400.0
      next if days <= 0

      rate = (id_hi - id_lo) / days
      rates << rate
      puts format('%-18s %-12s %14s %10.1f %14s',
                  delimited(id_hi), at_hi.to_date.iso8601, delimited(id_hi - id_lo), days, delimited(rate.round))
    end

    puts
    recent = rates.first(5)
    next if recent.empty?

    # The median, not the mean: on a restored dump the newest rows carry the
    # import date rather than their original created_at, which yields one wildly
    # understated interval at the top of the range. A mean would swallow it; a
    # median ignores it, and the deviation check below names it out loud.
    median = recent.sort[recent.size / 2]
    suspect = recent.filter { it < median / 3 || it > median * 3 }
    if suspect.any?
      puts "WARNING   : #{suspect.size} of the #{recent.size} most recent intervals deviate from the median"
      puts "            by more than 3x (#{suspect.map { delimited(it.round) }.join(', ')} ids/day)."
      puts "            On a restored dump this is the import date overwriting created_at."
    end

    days_left = (INT4_CEILING - max_id) / median
    puts "median of the #{recent.size} most recent intervals: #{delimited(median.round)} ids/day"
    puts "exhausted in #{delimited(days_left.round)} days (~#{(days_left / 365.25).round(1)} years), around #{Date.current + days_left.round}"
  end

  def delimited(number)
    ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: ' ')
  end
end
