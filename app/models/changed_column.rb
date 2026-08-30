# frozen_string_literal: true

class ChangedColumn
  delegate :label, :type, :id, :h_id, :stable_id, :label_for_value, to: :@column
  attr_reader :previous_value

  def initialize(column, value, previous_value)
    @column = column
    @value = value
    @previous_value = previous_value
  end

  def value(_ = nil) = @value

  class << self
    # `champs` are the champs carrying the change (a buffer stream, or the
    # champs merged at a checkpoint), `reference_champs` the champs they
    # replace. A reference champ without counterpart, or whose row `champs`
    # discards, is reported as removed.
    def columns(revision, champs, reference_champs)
      discarded_row_ids = champs.values.filter { it.row? && it.discarded? }.map(&:row_id).to_set
      champs = champs.reject { |_, champ| champ.row_id.in?(discarded_row_ids) }
      row_ids = (champs.values + reference_champs.values).map(&:row_id).compact.uniq.sort

      revision.public_root_type_de_champs.flat_map do |type_de_champ|
        if type_de_champ.repetition?
          prefix = type_de_champ.libelle
          type_de_champs = revision.children_of(type_de_champ)
          row_ids.flat_map do |row_id|
            type_de_champs.filter_map do |type_de_champ|
              public_id = type_de_champ.public_id(row_id)
              column = type_de_champ.change_column(procedure_id: revision.procedure_id, prefix:)
              diff_column(column, champs[public_id], reference_champs[public_id])
            end
          end
        else
          public_id = type_de_champ.public_id(nil)
          column = type_de_champ.change_column(procedure_id: revision.procedure_id)
          [diff_column(column, champs[public_id], reference_champs[public_id])].compact
        end
      end
    end

    private

    def diff_column(column, champ, reference_champ)
      return nil if column.nil? || (champ.nil? && reference_champ.nil?)

      value = column.value(champ)
      previous_value = column.value(reference_champ)
      return nil if comparable(column, value) == comparable(column, previous_value)

      new(column, value, previous_value)
    end

    # Attachments are cloned (new attachment rows) when a champ is copied to a
    # buffer stream, so compare the files themselves rather than the records.
    def comparable(column, value)
      return value if column.type != :attachments

      Array(value).map { it.blob.checksum }.sort
    end
  end
end
