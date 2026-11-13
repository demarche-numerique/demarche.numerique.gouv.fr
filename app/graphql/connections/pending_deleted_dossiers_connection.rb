# frozen_string_literal: true

module Connections
  class PendingDeletedDossiersConnection < CursorConnection
    def cursor_for(item)
      cursor_from_timestamp(self.class.hidden_at(item), item.id)
    end

    # Ruby counterpart of hidden_at_statement.
    def self.hidden_at(dossier)
      (dossier.hidden_by_user_at if dossier.en_construction?) || dossier.hidden_by_administration_at || dossier.hidden_by_expired_at
    end

    private

    def resolve_nodes(before:, after:, limit:, inverted:)
      order = inverted ? :desc : :asc
      hidden_at = hidden_at_statement

      nodes = items.order(hidden_at.public_send(order)).order(Dossier.arel_table[:id].public_send(order))
      nodes = nodes.limit(limit)

      if before.present?
        timestamp, id = timestamp_and_id_from_cursor(before)
        nodes.where("(#{hidden_at.to_sql}, dossiers.id) < (?, ?)", timestamp, id)
      elsif after.present?
        timestamp, id = timestamp_and_id_from_cursor(after)
        nodes.where("(#{hidden_at.to_sql}, dossiers.id) > (?, ?)", timestamp, id)
      else
        nodes
      end
    end

    # Same value as the historical key (user_at if en_construction, else administration_at) wherever
    # it was set, so cursors already stored by integrators stay valid.
    def hidden_at_statement
      dossiers_table = Dossier.arel_table
      user_statement = dossiers_table[:state].when(:en_construction).then(dossiers_table[:hidden_by_user_at])

      Arel::Nodes::NamedFunction.new('COALESCE', [
        user_statement,
        dossiers_table[:hidden_by_administration_at],
        dossiers_table[:hidden_by_expired_at],
      ])
    end
  end
end
