# frozen_string_literal: true

class Champs::CarteController < Champs::ChampController
  before_action :ensure_legitimate_access

  def index
    @focus = params[:focus].present?
  end

  def create
    geo_area = if cadastre_in_params?
      @champ.geo_areas.find_by("properties->>'id' = :id", id: create_params_feature[:properties][:id])
    end

    if geo_area.nil?
      geo_area = @champ.geo_areas.build(source: params_source, properties: {})

      if save_feature(geo_area, create_params_feature)
        @champ.update_timestamps
        FetchCadastreRealGeometryJob.perform_later(geo_area) if geo_area.cadastre?
        render json: { feature: geo_area.to_feature }, status: :created
      else
        render json: { errors: geo_area.errors.full_messages }, status: :unprocessable_content
      end
    else
      render json: { feature: geo_area.to_feature }, status: :ok
    end
  end

  def update
    geo_area = @champ.geo_areas.find(params[:id])

    if save_feature(geo_area, update_params_feature)
      @champ.update_timestamps
      FetchCadastreRealGeometryJob.perform_later(geo_area) if geo_area.cadastre?
      head :no_content
    else
      render json: { errors: geo_area.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @champ.geo_areas.find(params[:id]).destroy!
    @champ.update_timestamps

    head :no_content
  end

  private

  def params_source
    params[:source]
  end

  def cadastre_in_params? = params_source == GeoArea.sources.fetch(:cadastre)

  def create_params_feature
    params.require(:feature).permit(properties: [
      :filename,
      :description,
      :arpente,
      :commune,
      :contenance,
      :created,
      :id,
      :numero,
      :prefixe,
      :section,
      :updated,
    ]).tap do |feature|
      feature[:geometry] = params[:feature][:geometry]
    end
  end

  def update_params_feature
    params.require(:feature).permit(properties: [:description]).tap do |feature|
      feature[:geometry] = params[:feature][:geometry]
    end
  end

  def save_feature(geo_area, feature)
    if feature[:geometry]
      geo_area.geometry = feature[:geometry]
    end
    if feature[:properties]
      geo_area.properties.merge!(feature[:properties])
    end
    geo_area.save
  end

  def ensure_legitimate_access
    return if @champ.carte?

    head :not_found
  end
end
