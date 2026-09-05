# frozen_string_literal: true

class ProceduresFilter
  attr_reader :admin, :params

  ITEMS_PER_PAGE = 25
  PROCEDURE_ONLY_FILTERS = [:template, :for_individual, :libelle, :tags].freeze

  def initialize(admin, params)
    @admin = admin

    params[:zone_ids] = admin.zones.pluck(:id) if params[:zone_ids] == 'admin_default'

    @params = params.permit(:page, :libelle, :email, :from_publication_date, :service_siret, :service_departement, :template, tags: [], zone_ids: [], statuses: [], kind_usagers: [])
  end

  def admin_zones
    @admin_zones ||= admin.zones
  end

  def other_zones
    @other_zones ||= Zone.all - admin_zones
  end

  def zone_ids
    params[:zone_ids].presence&.compact_blank
  end

  def selected_zones
    Zone.where(id: zone_ids) if zone_ids.present?
  end

  def statuses
    params[:statuses].presence&.compact_blank
  end

  def tags
    params[:tags].compact_blank.uniq if params[:tags].present?
  end

  def kind_usagers
    params[:kind_usagers].presence&.compact_blank
  end

  def kind_usager_filtered?(kind_usager)
    kind_usagers&.include?(kind_usager)
  end

  def for_individual
    kind_usagers = params[:kind_usagers]
    if kind_usagers.present?
      kind_usagers.map { |k| k == "individual" }.uniq
    end
  end

  def template?
    ActiveRecord::Type::Boolean.new.cast(params[:template])
  end

  def service_siret
    params[:service_siret].presence
  end

  def service_departement
    params[:service_departement].presence
  end

  def from_publication_date
    return if params[:from_publication_date].blank?

    Date.parse(params[:from_publication_date])
  rescue Date::Error
    nil
  end

  def libelle
    ActiveRecord::Base.sanitize_sql_like(params[:libelle]).strip if params[:libelle].present?
  end

  def email
    ActiveRecord::Base.sanitize_sql_like(params[:email]).strip if params[:email].present?
  end

  def zone_filtered?(zone_id)
    zone_ids&.map(&:to_i)&.include?(zone_id)
  end

  def status_filtered?(status)
    statuses&.include?(status)
  end

  def procedure_only_filter?(name)
    PROCEDURE_ONLY_FILTERS.include?(name)
  end

  def without(filter, value = nil)
    if value.nil?
      params.to_h.except(filter)
    else
      new_filter = params.to_h[filter] - [value.to_s]
      params.to_h.merge(filter => new_filter)
    end
  end

  def to_s
    filters = []
    filters << selected_zones&.map { |zone| zone.current_label.parameterize }
    filters << libelle&.parameterize
    filters << email
    filters << "from-#{from_publication_date}" if from_publication_date
    filters << statuses
    filters << tags
    filters.compact.join('-')
  end
end
