# frozen_string_literal: true

module DossierEditConcern
  extend ActiveSupport::Concern

  private

  def update_champ_and_compute_errors(scope:)
    champ, champ_changed, refresh_external_data_requested = find_and_prepare_champ(scope:)
    return if champ.type_de_champ.pre_rempli?
    saved = save_champ(champ, champ_changed, scope)

    if saved && (champ_changed || refresh_external_data_requested)
      champ.update_timestamps if scope == :private || dossier.brouillon?
      refresh_external_data(champ, refresh_requested: refresh_external_data_requested)
      scope == :public ? after_public_champ_saved(champ) : after_private_champ_saved
    end

    validate_champ(champ, saved, scope)
  end

  def find_and_prepare_champ(scope:)
    param_key = :"champs_#{scope}_attributes"
    public_id, champ_attributes = champs_attributes_params(scope).to_h.first
    champ = dossier.send(:"#{scope}_champ_for_update", public_id, updated_by: current_user.email)

    if champ.referentiel? && champ.autocomplete?
      champ_attributes = champ_attributes.merge(params.require(:dossier).require(param_key).require(public_id).permit(:data).to_h)
    end
    refresh_external_data_requested = champ_attributes.delete("refresh_external_data") == "1"

    champ.assign_attributes(champ_attributes)
    champ_changed = champ.changed_for_autosave?

    [champ, champ_changed, refresh_external_data_requested]
  end

  def save_champ(champ, champ_changed, scope)
    if scope == :public
      Dossier.no_touching { champ.save }
    else
      champ_changed && champ.save
    end
  end

  def after_public_champ_saved(champ)
    if champ.used_by_routing_rules? && dossier.brouillon?
      @update_contact_information = true
      RoutingEngine.compute(dossier)
    end
  end

  def after_private_champ_saved
    dossier.index_search_terms_later
    DossierNotification.create_notification(dossier, :annotation_instructeur, except_instructeur: current_instructeur) if !dossier.brouillon?
  end

  def validate_champ(champ, saved, scope)
    validation_context = :"#{scope}_champs_value"
    should_validate = if scope == :public
      saved && params[:validate].present? && !champ.pending?
    else
      !champ.pending?
    end
    dossier.validate(validation_context) if should_validate
  end

  def refresh_external_data(champ, refresh_requested: false)
    if champ.has_async_external_data? || (refresh_requested && champ.france_connect?)
      reset_attrs = {}

      reset_attrs[:value] = nil if champ.france_connect?

      champ.reset_external_data!(reset_attrs)
      champ.fetch_later! if champ.may_fetch_later?
    end
  end

  # Strong attributes do not support records (indexed hash); they only support hashes with
  # static keys. We create a static hash based on the available keys.
  def champs_attributes_params(scope)
    param_key = :"champs_#{scope}_attributes"
    public_ids = params.dig(:dossier, param_key)&.keys || []

    champs_attributes = public_ids.index_with do |public_id|
      not_in_ban = params.dig(:dossier, param_key, public_id, :not_in_ban) == 'true'
      champ_permitted_attributes(scope, not_in_ban:)
    end

    params.require(:dossier).permit(param_key => champs_attributes).fetch(param_key)
  end

  def champ_permitted_attributes(scope, not_in_ban:)
    [
      :id, :value, :value_other, :external_id, :code,
      :primary_value, :secondary_value, :piece_justificative_file,
      :code_departement, :accreditation_number, :accreditation_birthdate,
      :not_in_ban,
      *([:preview_state, :refresh_external_data] if scope == :public),
      *(not_in_ban ? [:street_address, :city_name, :country_code, :commune_code, :postal_code] : [:address]),
      value: [],
    ].compact
  end
end
