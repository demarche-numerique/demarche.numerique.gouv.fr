# frozen_string_literal: true

# Domain model for a champ, projected from a dossier revision.
#
# A Champ is built by `Dossier#project_champ` from a `TypeDeChamp` (the shape,
# taken from the dossier revision) and an optional underlying `ChampData`
# (the persisted value on the current stream). It is never persisted itself.
#
# At projection time the outside-settable scalar columns of the champ data
# (value, value_json, data, external_id, prefilled) are copied into in-memory
# attributes: reads, writes and validation work on the copies without touching
# the database. Persisting requires a writable champ data instance, attached
# by `prepare_for_update!(updated_by)` (or `Champ.from_data` for jobs and
# maintenance tasks); `save`/`update` then validate and copy the changed
# attributes back to the champ data. Associations (etablissement, geo_areas,
# attachments) and machine-managed columns are not copied: they read through
# the champ data and their writers require a writable instance.
class Champ
  include ActiveModel::Model
  include ActiveModel::Validations::Callbacks
  extend ActiveModel::Callbacks

  define_model_callbacks :save

  # Attachment validators (size, content_type); railties only include it into
  # ActiveRecord::Base.
  include ActiveStorageValidations

  include ChampConditionalConcern
  include ChampValidateConcern
  include ChampExternalDataConcern
  include ChampStreamConcern

  # Error messages live under activerecord.errors.models.champ.* /
  # activerecord.errors.models.champs/*.
  def self.i18n_scope
    :activerecord
  end

  class NotImplemented < ::StandardError
    def initialize(method)
      super(":#{method} not implemented")
    end
  end

  NoDataError = Class.new(::StandardError)

  # Null object returned by `piece_justificative_file` when the champ has no
  # (consistent) champ data yet: renders as "nothing attached".
  class EmptyAttached
    include Enumerable

    def attached? = false
    def attachments = []
    def blobs = []
    def each(&) = [].each(&)

    def attach(*, **)
      raise NoDataError, 'can not attach a file to a champ without champ data'
    end
  end

  # `store_accessor`-compatible accessors over an in-memory jsonb attribute
  # copy (value_json or data). Readers dig into the copied hash; writers
  # reassign a merged copy so snapshot-based dirty tracking stays exact.
  # Generated in a module so subclasses can override a key accessor and call
  # `super`.
  module JsonStore
    def store_accessor(column, *keys)
      accessors = Module.new do
        keys.flatten.each do |key|
          key = key.to_s
          define_method(key) { public_send(column)&.dig(key) }
          define_method(:"#{key}=") do |value|
            update_json_attribute(column, key => value)
          end
          define_method(:"#{key}_changed?") do
            return false if !public_send(:"#{column}_changed?")
            public_send(column)&.dig(key) != public_send(:"#{column}_was")&.dig(key)
          end
          define_method(:"#{key}_was") { public_send(:"#{column}_was")&.dig(key) }
        end
      end
      include accessors
    end
  end
  extend JsonStore

  attr_reader :dossier, :type_de_champ, :row_id

  # The underlying champ data row: the writable instance once prepared for
  # update, the projection source otherwise (nil when the champ was never
  # filled).
  def champ_data
    @champ_data || @source_data
  end

  def prepared_for_update? = @champ_data.present?

  def initialize(dossier:, type_de_champ:, row_id: nil, data: nil)
    @dossier = dossier
    @type_de_champ = type_de_champ
    @row_id = row_id
    @source_data = data
    copy_attributes_from_data
  end

  # Upsert the champ data for this champ on the dossier current stream and
  # attach it as the writable instance. Required before any save/update;
  # reads and validation work without it.
  def prepare_for_update!(updated_by)
    pending_changes = changed?
    data = dossier.champ_data_for_update(type_de_champ, row_id:, updated_by:)
    @champ_data = @source_data = data
    # The upsert may have reset (champ type change) or cloned (new buffer row)
    # the underlying row; realign the copies unless they carry unsaved changes.
    copy_attributes_from_data if !pending_changes
    # The upsert reset the dossier projection cache: re-register this champ so
    # project_champ keeps returning the same (now writable) instance.
    dossier.register_projected_champ(self)
    self
  end

  # Attach the champ's own underlying row as the writable instance, bypassing
  # the stream upsert protocol. For jobs, maintenance tasks and test setup
  # that write a specific row directly; application update flows must go
  # through `prepare_for_update!` / `Dossier#champ_for_update`.
  def writable!
    @champ_data = @source_data || raise(NoDataError, "champ #{id} has no underlying champ data")
    self
  end

  # Rebuild the projected champ persisted champ data belongs to, writable.
  # Returns nil for orphaned champ data (type de champ no longer in the
  # dossier revision) or when the projection resolves to other champ data.
  def self.from_data(data)
    dossier = data.dossier
    return nil if dossier.nil?

    type_de_champ = dossier.find_type_de_champ_by_stable_id(data.stable_id)
    return nil if type_de_champ.nil?

    dossier.with_champ_stream(data)
    champ = dossier.project_champ(type_de_champ, row_id: data.row_id)
    # The projection resolved to the given row: attach it as writable (jobs
    # and maintenance tasks write outside the champ_for_update protocol).
    champ.writable! if champ.champ_data_id == data.id
  rescue RuntimeError
    nil
  end

  # GlobalID shim: job payloads enqueued before the split serialize champs as
  # gid://…/Champs::XChamp/<id>. Deserialize them to the underlying champ data.
  # TODO: remove once queues have drained.
  def self.find(id)
    ChampData.find(id)
  end

  # ActiveModel::Validations defines valid?(context) but not the
  # validate(context) alias ActiveRecord has; dossier validation uses it.
  def validate(context = nil)
    valid?(context)
  end

  # -- identity ---------------------------------------------------------------

  def stable_id
    type_de_champ.stable_id
  end

  # The champ identity within a dossier: "stable_id" or "stable_id-row_id".
  # The underlying champ data row PK stays behind `champ_data_id`.
  def id
    TypeDeChamp.public_id(stable_id, row_id)
  end

  # The underlying champ data row PK, for set-based SQL over the champs table.
  delegate :id, to: :champ_data, prefix: true, allow_nil: true

  # ActiveModel::Conversion returns nil when not persisted?; champ identity
  # exists regardless of persistence.
  def to_param
    id
  end

  # A champ counts as persisted when a value of the right shape exists; a
  # wrong-type champ data (revision changed the champ type) behaves like a blank,
  # unsaved champ (excluded from filled_champs).
  def persisted?
    consistent_data.present?
  end

  def new_record?
    !persisted?
  end

  # Projections are rebuilt at will; two projections of the same champ over
  # the same champ data are the same champ (ActiveRecord compared records by id).
  def ==(other)
    other.is_a?(Champ) &&
      other.class == self.class &&
      other.dossier == dossier &&
      other.id == id &&
      other.champ_data_id == champ_data_id
  end
  alias_method :eql?, :==

  def hash
    [self.class, id, champ_data_id].hash
  end

  def is_type?(type_champ)
    self.type_champ == type_champ
  end

  def last_write_type_champ
    champ_data.present? ? champ_data.last_write_type_champ : type_champ
  end

  # The class name, like the historical STI type column on the projected champ.
  def type
    self.class.name
  end

  def main_value_name
    :value
  end

  # -- in-memory attributes ---------------------------------------------------
  #
  # Copies of the outside-settable scalar columns of the champ data, seeded at
  # projection time. JSON attributes are normalized to string keys and
  # deep-frozen: mutate them by reassignment (see JsonStore /
  # update_json_attribute), never in place. Dirty tracking compares against
  # the snapshot taken at projection (or after the last save).
  DATA_ATTRIBUTES = [:value, :value_json, :data, :external_id, :prefilled].freeze
  Snapshot = ::Data.define(*DATA_ATTRIBUTES)

  attr_reader(*DATA_ATTRIBUTES)

  # Mirror the text column cast champ data applied when values were assigned
  # to it directly (numbers become strings, etc.).
  STRING_TYPE = ActiveModel::Type::String.new
  private_constant :STRING_TYPE

  def value=(value)
    @value = STRING_TYPE.cast(value)
  end

  def external_id=(external_id)
    @external_id = STRING_TYPE.cast(external_id)
  end

  def value_json=(value_json)
    @value_json = self.class.cast_json(value_json)
  end

  def data=(data)
    @data = self.class.cast_json(data)
  end

  def prefilled=(prefilled)
    @prefilled = prefilled
  end

  DATA_ATTRIBUTES.each do |attribute|
    define_method(:"#{attribute}_changed?") { public_send(attribute) != @snapshot.public_send(attribute) }
    define_method(:"#{attribute}_was") { @snapshot.public_send(attribute) }
  end

  def changed?
    DATA_ATTRIBUTES.any? { public_send(:"#{_1}_changed?") }
  end

  # Attachment and association writes go through the champ data; account for
  # them next to the in-memory attribute changes.
  def changed_for_autosave?
    changed? || champ_data&.changed_for_autosave? || false
  end

  # Mirrors the jsonb column cast: strings are parsed (and kept as-is when
  # they are not valid JSON), hash keys are stringified. Containers are frozen
  # so in-place mutations (which would corrupt snapshot-based dirty tracking)
  # fail fast.
  def self.cast_json(value)
    value = (ActiveSupport::JSON.decode(value) rescue value) if value.is_a?(::String)
    deep_freeze_json(value)
  end

  def self.deep_freeze_json(value)
    case value
    when ::Hash
      value.transform_keys(&:to_s).transform_values { deep_freeze_json(_1) }.freeze
    when ::Array
      value.map { deep_freeze_json(_1) }.freeze
    else
      value
    end
  end

  # -- champ data delegation (reads) ------------------------------------------

  def data?
    data.present?
  end

  def etablissement
    consistent_data&.etablissement
  end

  def etablissement_id
    consistent_data&.etablissement_id
  end

  def geo_areas
    consistent_data&.geo_areas || GeoArea.none
  end

  def piece_justificative_file
    consistent_data&.piece_justificative_file || EmptyAttached.new
  end

  def piece_justificative_file_attachments
    consistent_data&.piece_justificative_file_attachments || ActiveStorage::Attachment.none
  end

  # Read by attachment validators (active_storage_validations).
  def attachment_changes
    champ_data&.attachment_changes || {}
  end

  def updated_at
    champ_data&.updated_at || dossier.depose_at || dossier.created_at
  end

  def created_at
    champ_data&.created_at
  end

  def dossier_id
    dossier.id
  end

  def stream
    champ_data&.stream || dossier.stream
  end

  delegate :checkpoint, :source_stream, :updated_by, :rebased_at, to: :champ_data, allow_nil: true

  def prefilled?
    prefilled || false
  end

  def discarded?
    champ_data&.discarded? || false
  end

  # -- writers (require a writable champ data) ---------------------------------
  #
  # Associations, attachments and machine-managed columns are not part of the
  # in-memory copies: they write through to the underlying row.

  def etablissement=(etablissement)
    champ_data!.etablissement = etablissement
  end

  def build_etablissement(attributes = {})
    champ_data!.build_etablissement(attributes)
  end

  def etablissement_id=(etablissement_id)
    champ_data!.etablissement_id = etablissement_id
  end

  def geo_areas=(geo_areas)
    champ_data!.geo_areas = geo_areas
  end

  def piece_justificative_file=(attachable)
    champ_data!.piece_justificative_file = attachable
  end

  def updated_by=(updated_by)
    champ_data!.updated_by = updated_by
  end

  def external_state=(external_state)
    champ_data!.external_state = external_state
  end

  def fetch_external_data_exceptions=(exceptions)
    champ_data!.fetch_external_data_exceptions = exceptions
  end

  # -- persistence facade -------------------------------------------------------
  #
  # All save/update methods require a writable champ data instance (see
  # `prepare_for_update!`): they validate the in-memory attributes if needed,
  # then copy the changed ones to the champ data and save it.

  def save(validate: true, context: nil)
    data = champ_data!

    run_callbacks(:save) do
      if !validate || valid?(context || default_save_context)
        copy_attributes_to_data(data)
        saved = data.save
        take_snapshot if saved
        saved
      else
        false
      end
    end
  end

  def save!(**options)
    save(**options) || raise(ActiveModel::ValidationError, self)
  end

  def update(attributes)
    assign_attributes(attributes)
    save
  end

  def update!(attributes)
    assign_attributes(attributes)
    save!
  end

  # Escape hatches: write the underlying row directly, bypassing validation
  # and the writable instance protocol; the in-memory copies are refreshed to
  # match what was written.
  def update_columns(attributes)
    data_for_direct_write.update_columns(attributes)
    refresh_copied_attributes(attributes.keys)
  end

  def update_column(column, value)
    update_columns(column => value)
  end

  def update_attribute(attribute, value)
    data_for_direct_write.update_attribute(attribute, value)
    refresh_copied_attributes([attribute])
  end

  # Like ActiveRecord, reload discards unsaved in-memory changes.
  def reload(...)
    champ_data&.reload(...)
    copy_attributes_from_data
    self
  end

  def update_timestamps
    return if public? && dossier.en_construction?

    updated_at = Time.zone.now
    champ_data.update_columns(updated_at:) if champ_data&.persisted?

    attributes = { updated_at: }
    if private?
      attributes[:last_champ_private_updated_at] = updated_at
    else
      attributes[:last_champ_updated_at] = updated_at
      attributes[:brouillon_close_to_expiration_notice_sent_at] = nil
    end

    if dossier.brouillon?
      attributes[:expired_at] = (updated_at + dossier.duree_totale_conservation_in_months.months)
    end

    dossier.update_columns(attributes)
  end

  def clear
    champ_data&.clear
  end

  def discard!
    champ_data!.discard!
  end

  # -- type de champ delegation -------------------------------------------------

  delegate :libelle,
    :type_champ,
    :description,
    :max_file_size_bytes,
    :allowed_content_types,
    :titre_identite?,
    :pj_limit_formats?,
    :pj_format_families,
    :pj_auto_purge?,
    :drop_down_options,
    :drop_down_other?,
    :value_is_in_options?,
    :options_for_select,
    :options_for_select_with_other,
    :drop_down_secondary_libelle,
    :drop_down_secondary_description,
    :drop_down_simple?,
    :drop_down_advanced?,
    :collapsible_explanation_enabled?,
    :collapsible_explanation_text,
    :header_section_level_value,
    :current_section_level,
    :non_fillable?,
    :fillable?,
    :mandatory?,
    :prefillable?,
    :refresh_after_update?,
    :formatted_simple?,
    :formatted_advanced?,
    :positive_number,
    :positive_number?,
    :min_number,
    :max_number,
    :range_number,
    :range_number?,
    :birthdate,
    :birthdate?,
    :date_in_past,
    :date_in_past?,
    :range_date,
    :range_date?,
    :start_date,
    :end_date,
    :character_limit?,
    :character_limit,
    :letters_accepted,
    :numbers_accepted,
    :special_characters_accepted,
    :min_character_length,
    :max_character_length,
    :expression_reguliere,
    :expression_reguliere_exemple_text,
    :expression_reguliere_error_message,
    :pre_rempli_hidden?,
    :rib?,
    :france_connect?,
    :justificatif_domicile?,
    :avis_impot?,
    :ocr_compatible?,
    to: :type_de_champ

  delegate(*TypeDeChamp.type_champs.values.map { "#{_1}?".to_sym }, to: :type_de_champ)
  delegate :any_drop_down_list?, to: :type_de_champ

  delegate :to_typed_id, :to_typed_id_for_query, to: :type_de_champ, prefix: true

  delegate :procedure, to: :dossier
  delegate :revision, to: :dossier, prefix: true

  # -- domain -------------------------------------------------------------------

  def public?
    !type_de_champ.private?
  end

  def private?
    type_de_champ.private?
  end

  # Champs that can surface an external/async status message (rendered by
  # Dsfr::InputStatusMessageComponent) and therefore need a persistent
  # live region to announce it to screen readers.
  def status_announceable?
    siret? || rna? || referentiel? || dossier_link? || piece_justificative?
  end

  def prefilled_from_france_connect_information?
    data&.dig("prefilled_from_france_connect_information") == true
  end

  def child?
    row_id.present? && !repetition?
  end

  def parent
    return nil if row_id.blank?

    dossier.revision.parent_of(type_de_champ)
  end

  def row?
    row_id.present? && repetition?
  end

  # used for the `required` html attribute
  # check visibility to avoid hidden required input
  # which prevent the form from being sent.
  def required?
    type_de_champ.mandatory? && visible?
  end

  def mandatory_blank?
    type_de_champ.mandatory_blank?(self)
  end

  def libelle_for_error
    libelle
  end

  def blank?
    type_de_champ.champ_blank?(self)
  end

  # Mirrors ActiveRecord semantics: records are never blank as objects, so
  # `champ.present?` means "there is a champ" while `champ.blank?` means
  # "the champ has no value".
  def present?
    true
  end

  def used_by_routing_rules?
    procedure.used_by_routing_rules?(type_de_champ)
  end

  def search_terms
    [to_s]
  end

  def to_s
    type_de_champ.champ_value(self) || ''
  end

  def champ_descriptor_id
    type_de_champ.to_typed_id
  end

  def to_typed_id
    if row_id.present?
      GraphQL::Schema::UniqueWithinType.encode('Champ', "#{stable_id}|#{row_id}")
    else
      type_de_champ.to_typed_id
    end
  end

  def self.decode_typed_id(typed_id)
    _, stable_id_with_maybe_row = GraphQL::Schema::UniqueWithinType.decode(typed_id)
    stable_id_with_maybe_row.split('|')
  end

  def prefillable_champs
    []
  end

  def status_message?
    false
  end

  # -- html ids -----------------------------------------------------------------

  def html_label?
    true
  end

  def legend_label?
    false
  end

  def single_checkbox?
    false
  end

  def input_group_id
    html_id
  end

  # A predictable string to use when generating an input name for this champ.
  #
  # Rail's FormBuilder can auto-generate input names, using the form "dossier[champs_public_attributes][5]",
  # where [5] is the index of the field in the form.
  # However the field index makes it difficult to render a single field, independent from the ordering of the others.
  # Luckily, this is only used to make the name unique, but the actual value is ignored when Rails parses nested
  # attributes. So instead of the field index, this method uses the champ id; which gives us an independent and
  # predictable input name.
  def input_name
    if private?
      "dossier[champs_private_attributes][#{id}]"
    else
      "dossier[champs_public_attributes][#{id}]"
    end
  end

  def describedby_id
    "#{html_id}-describedby_id"
  end

  def error_id(attribute)
    [html_id, 'error_id', attribute].compact.join('-')
  end

  def focusable_input_id(attribute = :value)
    [input_id, attribute].compact.join('-')
  end

  def html_id
    type_de_champ.html_id(row_id)
  end

  private

  # The writable champ data instance. Present after `prepare_for_update!` (or
  # when the champ was built by `Champ.from_data`).
  def champ_data!
    @champ_data || raise(NoDataError, "champ #{id} has no writable champ data (call prepare_for_update! first)")
  end

  # The champ data, only when it was written with the champ type the revision
  # expects; a wrong-type champ data only contributes its raw value.
  def consistent_data
    data = champ_data
    data if data&.is_type?(type_de_champ.type_champ)
  end

  # Seed the in-memory attribute copies from the underlying champ data. The
  # raw value is carried over even when the champ data was written with
  # another champ type (revision type change): it is what the user sees and
  # submits, and it is validated against the new type. The other attributes
  # only carry over from consistent champ data.
  def copy_attributes_from_data
    data = champ_data
    consistent = (data if data&.is_type?(type_de_champ.type_champ))
    @value = data&.value
    @external_id = consistent&.external_id
    # Values read from the row are already column-cast: only normalize/freeze.
    @value_json = self.class.deep_freeze_json(consistent&.value_json)
    @data = self.class.deep_freeze_json(consistent&.data)
    @prefilled = data&.prefilled
    take_snapshot
  end

  def take_snapshot
    @snapshot = Snapshot.new(value:, value_json:, data:, external_id:, prefilled:)
  end

  def data_for_direct_write
    champ_data || raise(NoDataError, "champ #{id} has no underlying champ data")
  end

  # After a direct row write, realign the touched in-memory copies (and their
  # snapshot, so they don't read as dirty).
  def refresh_copied_attributes(keys)
    data = champ_data
    keys.map(&:to_sym).intersection(DATA_ATTRIBUTES).each do |attribute|
      fresh = data.public_send(attribute)
      fresh = self.class.deep_freeze_json(fresh) if attribute.in?([:value_json, :data])
      instance_variable_set(:"@#{attribute}", fresh)
      @snapshot = @snapshot.with(attribute => fresh)
    end
  end

  def copy_attributes_to_data(target)
    target.value = value if value_changed?
    target.external_id = external_id if external_id_changed?
    target.value_json = value_json.deep_dup if value_json_changed?
    target.data = data.deep_dup if data_changed?
    target.prefilled = prefilled if prefilled_changed?
  end

  # Reassign a merged copy of a jsonb attribute; the attribute hashes are
  # frozen, so this is the only way for subclasses to update a key.
  def update_json_attribute(column, changes)
    public_send(:"#{column}=", (public_send(column) || {}).merge(changes.transform_keys(&:to_s)))
  end

  def update_value_json(changes)
    update_json_attribute(:value_json, changes)
  end

  def default_save_context
    champ_data!.new_record? ? :create : :update
  end

  # The input id is used to generate the HTML id of the input element.
  # It is used to link the label to the input, and for ARIA attributes.
  def input_id
    "#{html_id}-input"
  end
end
