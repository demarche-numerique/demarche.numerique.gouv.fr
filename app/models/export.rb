# frozen_string_literal: true

class Export < ApplicationRecord
  include TransientModelsWithPurgeableJobConcern

  self.ignored_columns += ["procedure_presentation_snapshot"]

  MAX_DUREE_CONSERVATION_EXPORT = 32.hours
  MAX_DUREE_GENERATION = 16.hours

  enum :format, {
    csv: 'csv',
    ods: 'ods',
    xlsx: 'xlsx',
    zip: 'zip',
    json: 'json',
  }, prefix: true

  enum :time_span_type, {
    everything: 'everything',
    monthly:    'monthly',
  }

  enum :statut, {
    'a-suivre': 'a-suivre',
    suivis: 'suivis',
    traites: 'traites',
    tous: 'tous',
    supprimes: 'supprimes',
    archives: 'archives',
    expirant: 'expirant',
  }

  has_and_belongs_to_many :groupe_instructeurs
  belongs_to :procedure_presentation, optional: true
  belongs_to :instructeur, optional: true
  belongs_to :user_profile, polymorphic: true, optional: true
  belongs_to :export_template, optional: true

  has_one_attached :file

  attribute :sorted_column, :sorted_column
  attribute :filtered_columns, :filtered_column, array: true

  validates :format, :groupe_instructeurs, :key, presence: true

  scope :ante_chronological, -> { order(updated_at: :desc) }

  after_create_commit :compute_async

  FORMATS_WITH_TIME_SPAN = [:xlsx, :ods, :csv].flat_map do |format|
    [{ format: format, time_span_type: 'everything' }]
  end
  FORMATS = [:xlsx, :ods, :csv, :zip, :json].map do |format|
    { format: format }
  end

  def compute_async
    ExportJob.perform_later(self)
  end

  def compute
    self.dossiers_count = dossiers_for_export.count

    file.attach(blob.signed_id) # attaching a blob directly might run identify/virus scanner and wipe it
  end

  def since
    time_span_type == Export.time_span_types.fetch(:monthly) ? 30.days.ago : nil
  end

  def self.find_or_create_fresh_export(format, groupe_instructeurs, user_profile, time_span_type: time_span_types.fetch(:everything), statut: statuts.fetch(:tous), procedure_presentation: nil, export_template: nil, include_archived: false)
    filtered_columns = Array.wrap(procedure_presentation&.filters_for(statut))
    sorted_column = procedure_presentation&.sorted_column

    attributes = {
      format:,
      export_template:,
      time_span_type:,
      statut:,
      include_archived:,
      key: generate_cache_key(filtered_columns, sorted_column),
    }

    recent_export = pending
      .or(generated.where(updated_at: (5.minutes.ago)..))
      .joins(:groupe_instructeurs)
      .where(groupe_instructeurs: { id: groupe_instructeurs })
      .includes(:procedure_presentation)
      .find_by(attributes)

    return recent_export if recent_export.present?

    create!(**attributes, groupe_instructeurs:,
                          user_profile:,
                          filtered_columns:,
                          sorted_column:)
  end

  def self.for_groupe_instructeurs(groupe_instructeurs_ids)
    joins(:groupe_instructeurs)
      .where(groupe_instructeurs: groupe_instructeurs_ids)
      .where.not(id: joins(:groupe_instructeurs).where.not(groupe_instructeurs: groupe_instructeurs_ids))
      .distinct
  end

  def self.generate_cache_key(filtered_columns = [], sorted_column = nil)
    columns_key = ([sorted_column] + filtered_columns).compact.map(&:id).sort.join

    [
      Digest::MD5.hexdigest(columns_key),
    ].join('--')
  end

  def count
    return dossiers_count if !dossiers_count.nil? # export generated
    return dossiers_for_export.count if built_from_procedure_presentation?

    nil
  end

  def procedure
    groupe_instructeurs.first.procedure
  end

  def built_from_procedure_presentation?
    sorted_column.present? # hack has we know that procedure_presentation always has a sorted_column
  end

  private

  def dossiers_for_export
    @dossiers_for_export ||= begin
      dossiers = Dossier.where(groupe_instructeur: groupe_instructeurs)

      if since.present?
        dossiers.visible_by_administration.where('dossiers.depose_at > ?', since)
      elsif filtered_columns.present? || sorted_column.present?
        instructeur = instructeur_from(user_profile)
        filtered_sorted_ids = DossierFilterService.filtered_sorted_ids(dossiers, statut, filtered_columns, sorted_column, instructeur, include_archived: include_archived)

        dossiers.where(id: filtered_sorted_ids)
      else
        dossiers.visible_by_administration
      end
    end
  end

  def instructeur_from(user_profile)
    case user_profile
    when Administrateur
      user_profile.instructeur
    when Instructeur
      user_profile
    end
  end

  def blob
    service = ProcedureExportService.new(procedure, dossiers_for_export, user_profile, export_template)

    case format.to_sym
    when :csv
      service.to_csv
    when :xlsx
      service.to_xlsx
    when :ods
      service.to_ods
    when :zip
      service.to_zip
    when :json
      service.to_geo_json
    end
  end
end
