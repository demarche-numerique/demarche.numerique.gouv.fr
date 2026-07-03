# frozen_string_literal: true

# Persistence model for champ values, one row per (dossier, stream, stable_id,
# row_id). Domain behavior (type de champ delegation, validation, visibility,
# casts) lives on the projected Champ domain model; ChampData only keeps
# columns, associations, the external data state machine and cheap
# column-derived helpers used by the dossier stream machinery.
class ChampData < ApplicationRecord
  include ChampStreamConcern

  self.table_name = 'champs'
  self.ignored_columns += [:type_de_champ_id, :parent_id]

  # The `type` column records the champ class of the last write; rows are no
  # longer instantiated through STI (Champs::* classes are not ActiveRecord
  # models anymore).
  self.inheritance_column = nil

  # Polymorphic references (active_storage_attachments.record_type) predate the
  # rename and store 'Champ'; keep writing the historical name so old and new
  # rows stay uniform. The read side is resolved by
  # ChampDataPolymorphicNameResolution (initializer).
  def self.polymorphic_name
    'Champ'
  end

  # i18n lookups and dom ids predate the rename.
  def self.model_name
    @champ_model_name ||= ActiveModel::Name.new(self, nil, 'Champ')
  end

  attr_readonly :stable_id

  belongs_to :dossier, inverse_of: false, touch: true, optional: false
  has_many_attached :piece_justificative_file

  # We declare champ specific relationships (Champs::CarteChamp, Champs::SiretChamp and Champs::RepetitionChamp)
  # here because otherwise we can't easily use includes in our queries.
  has_many :geo_areas, -> { order(:created_at) }, dependent: :destroy, inverse_of: :champ
  # inverse_of can no longer be inferred automatically: Rails derives the
  # inverse name from the defining class (:champ_data), but the association
  # on the other side is still named :champ.
  belongs_to :etablissement, optional: true, dependent: :destroy, inverse_of: :champ

  delegate :procedure, to: :dossier
  normalizes :value, with: NORMALIZES_NON_PRINTABLE_PROC

  # Reading any `store_accessor` attribute (e.g. `country_code`,
  # `code_departement`) on a champ whose JSON column is nil silently
  # initializes that column to `{}`. Left as-is, this empty hash is persisted as
  # a spurious change — bumping `updated_at` and making an untouched blank champ
  # look like it was edited. Revert blank-equivalent JSON columns before saving.
  before_save :nullify_blank_json_columns

  scope :updated_since?, -> (date) { where('champs.updated_at > ?', date) }
  scope :prefilled, -> { where(prefilled: true) }
  scope :public_only, -> { where(private: false) }
  scope :private_only, -> { where(private: true) }

  include AASM
  attribute :fetch_external_data_exceptions, :external_data_exception, array: true

  # useful to serialize idle as nil
  # otherwise, all the champs are marked as dirty and saved on first dossier.save
  enum :external_state, {
    idle: nil, # initial state
    waiting_for_job: 'waiting_for_job',
    fetching: 'fetching',
    fetched: 'fetched',
    external_error: 'external_error',
  }

  # Pure transitions: guards and side effects (enqueueing jobs, applying
  # fetched data) are driven from the Champ domain model
  # (ChampExternalDataConcern).
  aasm column: :external_state, enum: true do
    state :idle, initial: true
    state :waiting_for_job
    state :fetching
    state :fetched
    state :external_error

    event :fetch_later do
      transitions from: :idle, to: :waiting_for_job
    end

    event :fetch do
      transitions from: [:waiting_for_job], to: :fetching
    end

    event :external_data_fetched do
      transitions from: [:fetching], to: :fetched
    end

    event :external_data_error do
      transitions from: [:waiting_for_job, :fetching], to: :external_error
    end

    event :retry do
      transitions from: [:fetching], to: :waiting_for_job
    end

    event :reset_external_data do
      transitions from: [:idle, :waiting_for_job, :fetching, :fetched, :external_error], to: :idle
    end
  end

  def public_id
    TypeDeChamp.public_id(stable_id, row_id)
  end

  def public?
    !private?
  end

  def last_write_type_champ
    TypeDeChamp::CHAMP_TYPE_TO_TYPE_CHAMP.fetch(type)
  end

  def is_type?(type_champ)
    last_write_type_champ == type_champ
  end

  def row?
    row_id.present? && is_type?(TypeDeChamp.type_champs.fetch(:repetition))
  end

  def discarded?
    discarded_at.present?
  end

  def discard!
    touch(:discarded_at)
  end

  def clear
    update_columns(value: nil, value_json: nil, external_id: nil, data: nil)
    ChampData.no_touching do
      etablissement&.destroy
      geo_areas.destroy_all
      piece_justificative_file.purge_later
    end
  end

  def clone
    champ_attributes = [:private, :row_id, :type, :stable_id, :stream]
    value_attributes = !private? ? [:value, :value_json, :data, :external_id] : []
    relationships = !private? ? [:etablissement, :geo_areas] : []

    deep_clone(only: champ_attributes + value_attributes, include: relationships, validate: true) do |original, kopy|
      if original.is_a?(ChampData)
        kopy.write_attribute(:stable_id, original.stable_id)
        kopy.write_attribute(:stream, Dossier::MAIN_STREAM)
      end
      ClonePiecesJustificativesService.clone_attachments(original, kopy) if !private?
    end
  end

  def clone_value_from(champ)
    self.value = champ.value
    self.external_id = champ.external_id
    self.value_json = champ.value_json
    self.data = champ.data
    self.external_state = champ.external_state

    self.geo_areas = champ.geo_areas.map(&:dup)

    ClonePiecesJustificativesService.clone_attachments(champ, self)

    if champ.etablissement.present?
      self.etablissement = champ.etablissement.dup
      ClonePiecesJustificativesService.clone_attachments(champ.etablissement, self.etablissement)
    end

    save!
  end

  private

  def nullify_blank_json_columns
    [:value_json, :data].each do |column|
      next if !has_attribute?(column) || !public_send(:"#{column}_changed?")

      value = public_send(column)
      self[column] = nil if value.is_a?(Hash) && value.compact.blank?
    end
  end
end
