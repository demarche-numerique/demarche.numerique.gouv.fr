# frozen_string_literal: true

# In-memory LRU cache of parsed GraphQL documents, keyed by a digest of the
# query string. Re-parsing large documents on every request is a significant
# share of API v2 request time, and integrators replay the same stored or
# custom queries constantly. Parsed ASTs are immutable, so they are safe to
# share between requests and threads.
class API::V2::ParsedQueryCache
  MAX_ENTRIES = 100

  @store = {}
  @lock = Mutex.new

  class << self
    # Returns the parsed document for the given query string, or nil when the
    # string is blank or does not parse — callers then fall back to the
    # regular execution path so parse errors keep their standard GraphQL
    # error response.
    def fetch(query_string)
      return nil if query_string.blank?

      key = Digest::SHA256.digest(query_string)

      @lock.synchronize do
        if (document = @store.delete(key))
          return @store[key] = document
        end
      end

      # Parse outside the lock: a slow parse must not block other requests.
      # Two threads may race to parse the same document; last write wins.
      document = GraphQL.parse(query_string, max_tokens: API::V2::Schema.max_query_string_tokens)

      @lock.synchronize do
        @store.shift if @store.size >= MAX_ENTRIES && !@store.key?(key)
        @store[key] = document
      end
    rescue GraphQL::ParseError
      nil
    end

    def clear
      @lock.synchronize { @store.clear }
    end
  end
end
