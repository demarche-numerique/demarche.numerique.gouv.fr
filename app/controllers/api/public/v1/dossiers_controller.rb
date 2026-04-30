# frozen_string_literal: true

class API::Public::V1::DossiersController < API::Public::V1::BaseController
  before_action :retrieve_procedure

  def create
    dossier = Dossier.new(
      revision: @procedure.active_revision,
      state: Dossier.states.fetch(:brouillon),
      prefilled: true
    )
    dossier.build_default_values
    if dossier.save
      dossier.prefill!(PrefillChamps.new(dossier, params.to_unsafe_h).to_a, PrefillIdentity.new(dossier, identity_params).to_h)
      render json: serialize_dossier(dossier), status: :created
    else
      render_bad_request(dossier.errors.full_messages.to_sentence)
    end
  end

  def index
    prefill_token = Array.wrap(params.fetch(:prefill_token, [])).flat_map { _1.split(',') }
    dossiers = @procedure.dossiers.visible_by_user.prefilled.order(:created_at).where(prefill_token:)
    if dossiers.present?
      render json: dossiers.map { serialize_dossier(_1) }
    else
      render json: []
    end
  end

  private

  def identity_params
    params.permit(:identite_prenom, :identite_nom, :identite_genre).to_h
  end

  def serialize_dossier(dossier)
    if dossier.orphan?
      {
        dossier_url: commencer_url(@procedure.path, prefill_token: dossier.prefill_token),
        state: :prefilled,
      }
    else
      {
        state: dossier.state,
        submitted_at: dossier.depose_at&.iso8601,
        processed_at: dossier.processed_at&.iso8601,
      }
    end.merge(
      dossier_id: dossier.to_typed_id,
      dossier_number: dossier.id,
      dossier_prefill_token: dossier.prefill_token
    ).compact
  end

  def retrieve_procedure
    @procedure = Procedure.publiees_ou_brouillons.find_by(id: params[:id])
    render_not_found("procedure", params[:id]) if @procedure.blank?
  end
end
