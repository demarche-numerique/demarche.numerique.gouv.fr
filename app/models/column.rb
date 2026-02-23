# frozen_string_literal: true

class Column
  # include validations to enable procedure_presentation.validate_associate,
  # which enforces the deserialization of columns in the displayed_columns attribute
  # and raises an error if a column is not found
  include ActiveModel::Validations

  TYPE_DE_CHAMP_TABLE = 'type_de_champ'
  NOT_FILLED_VALUE = 'nil'

  attr_reader :table, :column, :label, :type, :filterable, :displayable, :mandatory
  attr_accessor :options_for_select

  def initialize(procedure_id:, table:, column:, label: nil, human_label: nil, type: :text, filterable: true, displayable: true, options_for_select: [], mandatory: true)
    @procedure_id = procedure_id
    @table = table
    @column = column
    @label = label || I18n.t(column, scope: [:activerecord, :attributes, :procedure_presentation, :fields, table])
    @human_label = human_label
    @type = type
    @filterable = filterable
    @displayable = displayable
    @options_for_select = options_for_select
    @mandatory = mandatory
  end

  def human_label = @human_label || label

  # the id is a String to be used in forms
  def id = h_id.to_json

  # the h_id is a Hash and hold enough information to find the column
  # in the ColumnType class, aka be able to do the h_id -> column conversion
  def h_id = { procedure_id: @procedure_id, column_id: }

  def ==(other) = h_id == other.h_id # using h_id instead of id to avoid inversion of keys

  def notifications? = [table, column] == ['notifications', 'notifications']
  def dossier_id? = [table, column] == ['self', 'id']
  def dossier_state? = [table, column] == ['self', 'state']
  def groupe_instructeur? = [table, column] == ['groupe_instructeur', 'id']
  def dossier_labels? = [table, column] == ['dossier_labels', 'label_id']
  def email? = [table, column] == ['user', 'email']
  def avis? = [table, column] == ['avis', 'question_answer']
  def type_de_champ? = table == TYPE_DE_CHAMP_TABLE

  def self.find(h_id)
    begin
      procedure = Procedure.with_discarded.find(h_id[:procedure_id])
    rescue ActiveRecord::RecordNotFound
      raise ActiveRecord::RecordNotFound.new("Column: unable to find procedure #{h_id[:procedure_id]} from h_id #{h_id}")
    end

    procedure.find_column(h_id: h_id)
  end

  def dossier_column? = false
  def champ_column? = false
  def filterable? = filterable

  def label_for_value(value)
    if value == NOT_FILLED_VALUE
      I18n.t('activerecord.attributes.type_de_champ.not_filled')
    elsif options_for_select.present?
      # options for select store ["trad", :enum_value]
      options_for_select.to_h { |(label, value)| [value.to_s, label] }
        .fetch(value.to_s, value.to_s)
    else
      value
    end
  end

  def self.not_filled_option = [I18n.t('activerecord.attributes.type_de_champ.not_filled'), NOT_FILLED_VALUE]

  private

  def column_id = "#{table}/#{column}"
end
