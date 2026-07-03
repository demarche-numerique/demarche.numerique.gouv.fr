# frozen_string_literal: true

module Maintenance
  module StatementsHelpersConcern
    extend ActiveSupport::Concern

    # Execute block in transaction with a local statement timeout.
    # A value of 0 disable the timeout.
    # IMPORTANT: it has NO effect if the block returns a lazy loaded collection, like an ActiveRecord::Relation!
    # Instead it should be used either when `collection` returns an enumerable object, or in `count`.
    #
    # Examples:
    # def collection
    #   with_statement_timeout("0") do
    #     ChampData.all.pluck(:id)
    #     # No effect with Dossier.all because the collection will be lazy loaded later in batches by MaintenanceTask.
    #   end
    # end
    #
    # def count
    #   with_statement_timeout("15min") do
    #     collection.count(:id)
    #   end
    # end
    def with_statement_timeout(timeout)
      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute("SET LOCAL statement_timeout = '#{timeout}'")
        yield
      end
    end
  end
end
