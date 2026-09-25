# frozen_string_literal: true

module QueryCounting
  # Counts the statements a block sends. `matching:` narrows to the ones whose
  # SQL it matches; without it, schema and transaction chatter is dropped.
  def count_queries(matching: nil)
    count = 0

    counter = lambda do |_name, _started, _finished, _id, payload|
      if matching.nil?
        next if %w[SCHEMA TRANSACTION CACHE].include?(payload[:name])
      else
        next if !payload[:sql].to_s.match?(matching)
      end

      count += 1
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { yield }

    count
  end
end

RSpec.configure do |config|
  config.include QueryCounting
end
