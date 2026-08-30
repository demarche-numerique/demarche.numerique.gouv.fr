# frozen_string_literal: true

# A Column narrowed to one change: the value the correction set and the one it
# replaced, scoped to one repetition row when the champ lives in one.
class ChangedColumn
  delegate_missing_to :@column
  attr_reader :row_id, :previous_value

  def initialize(column, value, previous_value, row_id: nil)
    @column = column
    @value = value
    @previous_value = previous_value
    @row_id = row_id
  end

  def value(_ = nil) = @value

  # A Column identifies a type de champ; a change inside a repetition is
  # identified by the row too, otherwise every corrected row shares one id.
  def h_id
    return @column.h_id if row_id.nil?

    @column.h_id.merge(column_id: "#{@column.h_id.fetch(:column_id)}-#{row_id}")
  end

  def id = h_id.to_json

  class << self
    def columns(revision, champs, reference_champs)
      row_ids = champs.values.map(&:row_id).compact.uniq.sort

      revision.public_root_type_de_champs.flat_map do |type_de_champ|
        if type_de_champ.repetition?
          prefix = type_de_champ.libelle
          type_de_champs = revision.children_of(type_de_champ)
          row_ids.flat_map do |row_id|
            type_de_champs.filter_map do |type_de_champ|
              public_id = type_de_champ.public_id(row_id)
              column = type_de_champ.canonical_column(procedure_id: revision.procedure_id, prefix:)
              diff_column(column, champs[public_id], reference_champs[public_id], row_id:)
            end
          end
        else
          public_id = type_de_champ.public_id(nil)
          column = type_de_champ.canonical_column(procedure_id: revision.procedure_id)
          [diff_column(column, champs[public_id], reference_champs[public_id])].compact
        end
      end
    end

    private

    def diff_column(column, champ, reference_champ, row_id: nil)
      return nil if column.nil? || champ.nil?

      value = column.value(champ)
      previous_value = column.value(reference_champ)
      return nil if comparable(column, value) == comparable(column, previous_value)

      new(column, value, previous_value, row_id:)
    end

    # Attachments are cloned (new attachment rows) when a champ is copied to a
    # buffer stream, so compare the files themselves rather than the records.
    def comparable(column, value)
      return value if column.type != :attachments

      Array(value).map { it.blob.checksum }.sort
    end
  end
end
