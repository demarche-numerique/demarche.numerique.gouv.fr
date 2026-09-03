# frozen_string_literal: true

module DossierChampsConcern
  extend ActiveSupport::Concern

  def project_champ(type_de_champ, row_id: nil)
    check_valid_row_id_on_read?(type_de_champ, row_id)
    data = champ_data_by_public_id[type_de_champ.public_id(row_id)]
    if data.nil? || !data.is_type?(type_de_champ.type_champ)
      value = type_de_champ.champ_blank?(data) ? nil : data.value
      updated_at = data&.updated_at || depose_at || created_at
      rebased_at = data&.rebased_at
      type_de_champ.build_champ(dossier: self, row_id:, updated_at:, rebased_at:, value:, stream:)
    else
      data.type_de_champ = type_de_champ
      data
    end
  end

  def root_champs_public
    @root_champs_public ||= revision.public_root_type_de_champs.map { project_champ(_1) }
  end

  def root_champs_private
    @root_champs_private ||= revision.private_root_type_de_champs.map { project_champ(_1) }
  end

  def champs
    root_champs_public + root_champs_private
  end

  def filled_champs_public
    @filled_champs_public ||= root_champs_public.flat_map do |champ|
      if champ.repetition?
        champ.rows.flatten.filter { _1.persisted? && _1.fillable? }
      elsif champ.persisted? && champ.fillable?
        champ
      else
        []
      end
    end
  end

  def filled_champs_private
    @filled_champs_private ||= root_champs_private.flat_map do |champ|
      if champ.repetition?
        champ.rows.flatten.filter { _1.persisted? && _1.fillable? }
      elsif champ.persisted? && champ.fillable?
        champ
      else
        []
      end
    end
  end

  def filled_champs
    filled_champs_public + filled_champs_private
  end

  def flat_champs_public
    @flat_champs_public ||= revision.public_root_type_de_champs.flat_map do |type_de_champ|
      champ = project_champ(type_de_champ)
      if type_de_champ.repetition?
        [champ] + project_rows_for(type_de_champ).flatten
      else
        champ
      end
    end
  end

  def flat_champs_private
    @flat_champs_private ||= revision.private_root_type_de_champs.flat_map do |type_de_champ|
      champ = project_champ(type_de_champ)
      if type_de_champ.repetition?
        [champ] + project_rows_for(type_de_champ).flatten
      else
        champ
      end
    end
  end

  def project_rows_for(type_de_champ)
    return [] if !type_de_champ.repetition?

    children = revision.children_of(type_de_champ)
    row_ids = repetition_row_ids(type_de_champ)

    row_ids.map do |row_id|
      children.map { project_champ(_1, row_id:) }
    end
  end

  def find_type_de_champ_by_stable_id(stable_id, scope = nil)
    case scope
    when :public
      public_type_de_champs_all
    when :private
      private_type_de_champs_all
    else
      revision.type_de_champs
    end.find { _1.stable_id == stable_id.to_i }
  end

  def public_type_de_champs_all
    revision.type_de_champs.filter(&:public?)
  end

  def private_type_de_champs_all
    revision.type_de_champs.filter(&:private?)
  end

  def champs_for_prefill(stable_ids)
    revision
      .type_de_champs
      .filter { _1.stable_id.in?(stable_ids) }
      .filter { !_1.child?(revision) }
      .map { _1.repetition? ? project_champ(_1) : champ_for_update(_1, updated_by: nil) }
  end

  def champ_value_for_tag(type_de_champ, path = :value)
    champ = if type_de_champ.repetition?
      project_champ(type_de_champ)
    else
      filled_champ(type_de_champ)
    end
    type_de_champ.champ_value_for_tag(champ, path)
  end

  def champ_for_update(type_de_champ, row_id: nil, updated_by:)
    champ = champ_upsert_by!(type_de_champ, row_id)
    champ.updated_by = updated_by
    champ
  end

  def public_champ_for_update(public_id, updated_by:)
    stable_id, row_id = public_id.split('-')
    type_de_champ = find_type_de_champ_by_stable_id(stable_id, :public)
    champ_for_update(type_de_champ, row_id:, updated_by:)
  end

  def private_champ_for_update(public_id, updated_by:)
    stable_id, row_id = public_id.split('-')
    type_de_champ = find_type_de_champ_by_stable_id(stable_id, :private)
    champ_for_update(type_de_champ, row_id:, updated_by:)
  end

  def repetition_rows_for_export(type_de_champ)
    repetition_row_ids(type_de_champ).map.with_index(1) do |row_id, index|
      Champs::RepetitionChamp::Row.new(index:, row_id:, dossier: self)
    end
  end

  def repetition_row_ids(type_de_champ)
    return [] if !type_de_champ.repetition?
    @repetition_row_ids ||= {}
    @repetition_row_ids[type_de_champ.stable_id] ||= champ_data_on_stream
      .filter { _1.row? && _1.stable_id == type_de_champ.stable_id && !_1.discarded? }
      .map(&:row_id)
      .sort
  end

  def repetition_add_row(type_de_champ, updated_by:)
    raise "Can't add row to non-repetition type de champ" if !type_de_champ.repetition?

    row_id = ULID.generate
    champ_for_update(type_de_champ, row_id:, updated_by:)
    row_id
  end

  def repetition_remove_row(type_de_champ, row_id, updated_by:)
    raise "Can't remove row from non-repetition type de champ" if !type_de_champ.repetition?

    champ = champ_for_update(type_de_champ, row_id:, updated_by:)
    champ.discard!
  end

  def stable_id_in_revision?(stable_id)
    revision_stable_ids.member?(stable_id.to_i)
  end

  def reload
    super.tap { reset_champs_cache }
  end

  def merge_user_buffer_stream!
    buffer_ids, changed_ids = changed_champ_data_ids_for_merge(Dossier::USER_BUFFER_STREAM)

    return if buffer_ids.blank?

    merge_buffer_champ_data(buffer_ids, changed_ids, Dossier::USER_BUFFER_STREAM)
  end

  def merge_instructeur_buffer_stream!
    buffer_ids, changed_ids = changed_champ_data_ids_for_merge(Dossier::INSTRUCTEUR_BUFFER_STREAM)

    return if buffer_ids.blank?

    merge_buffer_champ_data(buffer_ids, changed_ids, Dossier::INSTRUCTEUR_BUFFER_STREAM)
  end

  def reset_user_buffer_stream!
    champ_data.where(stream: Dossier::USER_BUFFER_STREAM).destroy_all

    # update loaded champ instances
    association(:champ_data).target = champ_data.reject(&:user_buffer_stream?)

    reset_champs_cache
  end

  def reset_instructeur_buffer_stream!
    champ_data.where(stream: Dossier::INSTRUCTEUR_BUFFER_STREAM).destroy_all

    # update loaded champ instances
    association(:champ_data).target = champ_data.reject(&:instructeur_buffer_stream?)

    reset_champs_cache
  end

  def user_buffer_changes?
    champ_data_on_user_buffer_stream.present?
  end

  def instructeur_buffer_changes?
    champ_data_on_instructeur_buffer_stream.present?
  end

  def history
    champ_data.filter(&:history_stream?)
  end

  def set_default_value_for_france_connect_champs(user_email)
    revision.public_root_type_de_champs.filter(&:france_connect?).each do |type_de_champ|
      existing_champ_data_on_main_stream = champ_data_on_main_stream.any? { _1.stable_id == type_de_champ.stable_id }

      next if existing_champ_data_on_main_stream && en_construction?

      champ = champ_for_update(type_de_champ, updated_by: user_email)

      champ.fetch_later! if champ.may_fetch_later?
    end
  end

  def user_changed_columns
    changed_columns_for(champ_data_on_user_buffer_stream)
  end

  def instructeur_changed_columns
    changed_columns_for(champ_data_on_instructeur_buffer_stream)
  end

  private

  # The reference champs are the main stream counterparts of the buffer champs,
  # plus the champs of the rows the buffer removes (they only exist on main).
  def changed_columns_for(buffer_champs)
    return [] if buffer_champs.blank?

    public_ids = buffer_champs.map(&:public_id).to_set
    discarded_row_ids = buffer_champs.filter { _1.row? && _1.discarded? }.map(&:row_id).to_set
    reference_champs = champ_data_on_main_stream.filter { _1.public_id.in?(public_ids) || _1.row_id.in?(discarded_row_ids) }

    ChangedColumn.columns(revision, buffer_champs.index_by(&:public_id), reference_champs.index_by(&:public_id))
  end

  def changed_champ_data_ids_for_merge(stream)
    stream_h = champ_data.where(stream:, stable_id: revision_stable_ids)
      .pluck(:stable_id, :row_id, :id)
      .to_h { |(stable_id, row_id, id)| [TypeDeChamp.public_id(stable_id, row_id), id] }

    return [[], []] if stream_h.empty?

    main_h = champ_data.where(stream: Dossier::MAIN_STREAM, stable_id: revision_stable_ids)
      .pluck(:stable_id, :row_id, :id)
      .to_h { |(stable_id, row_id, id)| [TypeDeChamp.public_id(stable_id, row_id), id] }

    main_public_ids = main_h.keys
    stream_public_ids = stream_h.keys

    changed_ids = main_public_ids.intersection(stream_public_ids).map { main_h[it] }
    stream_ids = stream_h.values

    # mark champ_data in discarded rows as changed
    discarded_row_ids = champ_data.where(stream:, stable_id: revision_stable_ids)
      .where.not(row_id: nil)
      .where.not(discarded_at: nil)
      .pluck(:row_id)

    if discarded_row_ids.present?
      changed_ids += champ_data.where(stream: Dossier::MAIN_STREAM, row_id: discarded_row_ids).pluck(:id)
    end

    [stream_ids, changed_ids]
  end

  def merge_buffer_champ_data(buffer_ids, changed_ids, stream)
    now = Time.zone.now
    history_stream = "#{Dossier::HISTORY_STREAM}#{now}"
    buffer_champ_data = champ_data.filter { buffer_ids.member?(it.id) }

    transaction do
      # if merging user buffer, discard any instructeur made changes
      if stream == Dossier::USER_BUFFER_STREAM
        champ_data.where(id: buffer_ids, stream:).pluck(:stable_id, :row_id).each do |(stable_id, row_id)|
          champ_data.where(stream: Dossier::INSTRUCTEUR_BUFFER_STREAM, stable_id:, row_id:).destroy_all
        end
      end

      # move champ_data with changes from "main" to "history" stream
      champ_data.where(id: changed_ids, stream: Dossier::MAIN_STREAM).update_all(stream: history_stream)
      # move champ_data from "buffer" to "main"
      champ_data.where(id: buffer_ids, stream:).update_all(stream: Dossier::MAIN_STREAM, updated_at: now, value_updated_at: now, checkpoint: history_stream)
      update_champs_timestamps(buffer_champ_data, stream)
    end

    # update loaded champ data instances
    champ_data.each do |data|
      if data.id.in?(changed_ids)
        data.stream = history_stream
      elsif data.id.in?(buffer_ids)
        data.stream = Dossier::MAIN_STREAM
        data.checkpoint = history_stream
      end
    end

    reset_champs_cache

    with_main_stream do
      prefill_and_enqueue_fetch_external_data_jobs(buffer_champ_data.filter(&:referentiel?), private_type_de_champs_all)
    end

    history_stream
  end

  def champ_data_by_public_id
    @champ_data_by_public_id ||= champ_data_on_stream.index_by(&:public_id)
  end

  def discarded_champ_data_by_public_id
    @discarded_champ_data_by_public_id ||= discarded_champ_data_on_main_stream.index_by(&:public_id)
  end

  def champ_data_on_stream
    @champ_data_on_stream ||= if user_buffer_stream?
      (champ_data_on_user_buffer_stream + champ_data_on_main_stream).uniq(&:public_id)
    elsif instructeur_buffer_stream?
      (champ_data_on_instructeur_buffer_stream + champ_data_on_main_stream).uniq(&:public_id)
    elsif user_history_stream?
      champ_data
        # only "main" and "history"
        .reject(&:buffer_stream?)
        # only updates made before last submission
        .filter { _1.updated_at <= en_construction_at }
        # take last change
        .sort_by(&:updated_at).reverse
        # compact
        .uniq(&:public_id)
    else
      champ_data_on_main_stream
    end
  end

  def revision_stable_ids
    @revision_stable_ids ||= revision.type_de_champs.map(&:stable_id).to_set
  end

  def champ_data_in_revision
    champ_data.filter { stable_id_in_revision?(_1.stable_id) }
  end

  def discarded_champ_data_on_main_stream
    champ_data.filter(&:main_stream?).reject { stable_id_in_revision?(_1.stable_id) }
  end

  def champ_data_on_main_stream
    champ_data_in_revision.filter(&:main_stream?)
  end

  def champ_data_on_user_buffer_stream
    champ_data_in_revision.filter(&:user_buffer_stream?)
  end

  def champ_data_on_instructeur_buffer_stream
    champ_data_in_revision.filter(&:instructeur_buffer_stream?)
  end

  def filled_champ(type_de_champ, row_id: nil, with_discarded: false)
    champ_public_id = type_de_champ.public_id(row_id)
    data = champ_data_by_public_id[champ_public_id]

    if data.nil? && with_discarded
      data = discarded_champ_data_by_public_id[champ_public_id]
    end

    return nil if type_de_champ.champ_blank?(data)

    if discarded_champ_data_by_public_id.key?(champ_public_id)
      data
    elsif !data.visible?
      nil
    else
      data
    end
  end

  def champ_upsert_by!(type_de_champ, row_id)
    check_valid_stream_on_write?(type_de_champ)
    check_valid_row_id_on_write?(type_de_champ, row_id)

    # Memory-first lookup: champ_data is (almost) always loaded here, and going
    # through create_or_find_by for an existing champ costs a savepoint plus an
    # insert/conflict roundtrip per call.
    data = champ_data.find { _1.stream == stream && _1.public_id == type_de_champ.public_id(row_id) }

    if data.nil?
      data = Dossier.no_touching do
        champ_data
          .create_with(**type_de_champ.params_for_champ, source_stream: stream)
          .create_or_find_by!(stable_id: type_de_champ.stable_id, row_id:, stream:)
      end
    end

    # Needed when a revision change the champ type in this case, we reset the champ data
    if data.class != type_de_champ.champ_class
      data = data.becomes!(type_de_champ.champ_class)
      # external_state must be reset too: a champ left "fetched" with nil data
      # crashes the components rendering the fetched external data
      data.assign_attributes(value: nil, value_json: nil, external_id: nil, data: nil, external_state: nil, fetch_external_data_exceptions: [])
    elsif !main_stream? && data.previously_new_record?
      main_stream_data = champ_data.find_by(stable_id: type_de_champ.stable_id, row_id:, stream: Dossier::MAIN_STREAM)
      data.clone_value_from(main_stream_data) if main_stream_data.present?
    end

    # If the champ data returned from `create_or_find_by` is not the same as the one already loaded in `dossier.champ_data`, we need to update the association cache
    loaded_data = champ_data.find { [_1.stream, _1.public_id] == [data.stream, data.public_id] }
    if loaded_data.present? && loaded_data.object_id != data.object_id
      association(:champ_data).target = champ_data - [loaded_data] + [data]
    end

    # If the dossier instance on the champ data has changed we need to update the association cache
    if data.dossier.object_id != object_id
      data.association(:dossier).target = self
    end

    reset_champs_cache

    data.save!
    data.type_de_champ = type_de_champ
    data
  end

  def check_valid_stream_on_write?(type_de_champ)
    if type_de_champ.private?
      if !main_stream?
        raise "Can not write a private champ to \"#{stream}\" stream"
      end
    elsif main_stream? && en_construction?
      raise 'Can not write to "main" stream on a dossier "en construction"'
    end
  end

  def check_valid_row_id_on_write?(type_de_champ, row_id)
    if type_de_champ.repetition?
      if row_id.blank?
        raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} must have a row_id because it represents a row in a repetition"
      end
    else
      check_valid_row_id_on_read?(type_de_champ, row_id)
    end
  end

  def check_valid_row_id_on_read?(type_de_champ, row_id)
    if type_de_champ.child?(revision)
      if row_id.blank?
        raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} must have a row_id because it is part of a repetition"
      end
    elsif row_id.present? && stable_id_in_revision?(type_de_champ.stable_id)
      raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} can not have a row_id because it is not part of a repetition"
    end
  end

  def reset_champs_cache
    @champ_data_by_public_id = nil
    @discarded_champ_data_by_public_id = nil
    @filled_champs_public = nil
    @filled_champs_private = nil
    @root_champs_public = nil
    @root_champs_private = nil
    @flat_champs_public = nil
    @flat_champs_private = nil
    @repetition_row_ids = nil
    @revision_stable_ids = nil
    @champ_data_on_stream = nil
  end
end
