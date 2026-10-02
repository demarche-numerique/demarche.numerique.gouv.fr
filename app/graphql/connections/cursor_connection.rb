# frozen_string_literal: true

module Connections
  class CursorConnection < GraphQL::Pagination::Connection
    def initialize(items, deprecated_order: nil, **kwargs)
      super(items, **kwargs)
      @deprecated_order = deprecated_order
    end

    def nodes
      load_nodes
    end

    def has_previous_page
      load_nodes
      @has_previous_page
    end

    def has_next_page
      load_nodes
      @has_next_page
    end

    def cursor_for(item)
      cursor_from_column(item, order_column)
    end

    private

    # [d1, d2, d3, d4, d5, d6]
    #
    # first: 2
    # -> d1, d2
    # first: 2, after: d2
    # -> d3, d4
    # first: 2, before: d3
    # -> d1, d2
    #
    # last: 2
    # -> d5, d6
    # last: 2, before: d5
    # -> d3, d4
    # last: 2, after: d4
    # -> d5, d6
    #
    # si after ou before present, last ou first donne juste limit
    def limit_and_inverted(first: nil, last: nil, after: nil, before: nil)
      limit = [first, last, max_page_size].compact.min + 1
      inverted = last.present? || before.present?

      [limit, inverted]
    end

    def previous_page?(after, result_size, limit, inverted)
      after.present? || (result_size == limit && inverted)
    end

    def next_page?(before, result_size, limit, inverted)
      before.present? || (result_size == limit && !inverted)
    end

    def load_nodes
      @nodes ||= begin
        ensure_valid_params
        limit, inverted = limit_and_inverted(first:, last:, after:, before:)

        return load_nodes_deprecated_order(limit, inverted) if @deprecated_order == :desc

        expected_size = limit - 1

        # Load the page once: `size` on an unloaded relation issues a COUNT that
        # repeats the page query, and that query is the expensive part.
        nodes = resolve_nodes(limit:, before:, after:, inverted:).to_a

        result_size = nodes.size
        @has_previous_page = previous_page?(after, result_size, limit, inverted)
        @has_next_page = next_page?(before, result_size, limit, inverted)

        trimmed_nodes = nodes.first(expected_size)
        trimmed_nodes.reverse! if inverted
        trimmed_nodes
      end
    end

    def load_nodes_deprecated_order(limit, inverted)
      payload = {
        message: "CursorConnection: using deprecated order [#{Current.user.email}]",
        user_id: Current.user.id,
      }
      logger = Lograge.logger || Rails.logger
      logger.info payload.to_json

      expected_size = limit - 1

      if before.nil?
        inverted = !inverted
      end

      nodes = resolve_nodes(limit:, before: after, after: before, inverted:).to_a

      result_size = nodes.size
      @has_next_page = previous_page?(before, result_size, limit, inverted)
      @has_previous_page = next_page?(after, result_size, limit, inverted)

      nodes.first(expected_size)
    end

    def ensure_valid_params
      if first.present? && last.present?
        raise GraphQL::ExecutionError.new('Arguments "first" and "last" are exclusive', extensions: { code: :bad_request })
      end

      if before.present? && after.present?
        raise GraphQL::ExecutionError.new('Arguments "before" and "after" are exclusive', extensions: { code: :bad_request })
      end

      if first.present? && first < 0
        raise GraphQL::ExecutionError.new('Argument "first" must be a non-negative integer', extensions: { code: :bad_request })
      end

      if last.present? && last < 0
        raise GraphQL::ExecutionError.new('Argument "last" must be a non-negative integer', extensions: { code: :bad_request })
      end

      if last.present? && @deprecated_order == :desc
        raise GraphQL::ExecutionError.new('Argument "last" is not supported with order "desc"', extensions: { code: :bad_request })
      end
    end

    def timestamp_and_id_from_cursor(cursor)
      timestamp, id = decode(cursor).split(';')
      [Time.zone.parse(timestamp), id.to_i]
    end

    def cursor_from_column(item, column)
      encode([item.read_attribute(column).utc.strftime("%Y-%m-%dT%H:%M:%S.%NZ"), item.id].join(';'))
    end

    def order_column
      :updated_at
    end

    def order_table
      raise StandardError, 'Not implemented'
    end

    def resolve_nodes(before:, after:, limit:, inverted:)
      order = inverted ? :desc : :asc
      nodes = items.order(order_column => order, id: order)
      nodes = nodes.limit(limit)

      if before.present?
        timestamp, id = timestamp_and_id_from_cursor(before)
        nodes.where("(#{order_table}.#{order_column}, #{order_table}.id) < (?, ?)", timestamp, id)
      elsif after.present?
        timestamp, id = timestamp_and_id_from_cursor(after)
        nodes.where("(#{order_table}.#{order_column}, #{order_table}.id) > (?, ?)", timestamp, id)
      else
        nodes
      end
    end
  end
end
