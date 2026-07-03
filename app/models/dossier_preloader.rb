# frozen_string_literal: true

class DossierPreloader
  DEFAULT_BATCH_SIZE = 2000
  # Plafonne le nombre de champs chargés par batch dans `load_dossiers`.
  # Le `SELECT` champs remonte les lignes du heap + détoaste les `value_json`
  # côté serveur : son temps croît avec le nombre de lignes. 140k saturait
  # le statement_timeout (60s) sur les grosses démarches (PG::QueryCanceled).
  # 40k ramène ce SELECT à ~6-8s sur les démarches les plus lourdes, soit une
  # large marge sous contention. Voir la PR pour les mesures.
  MAX_CHAMPS_PER_BATCH = 40_000

  # Associations préchargées pour l'export tableur (feuilles Dossiers/Etablissements/Avis).
  SHEET_EXPORT_INCLUDES = [
    :user, :individual, :followers_instructeurs, :traitement, :groupe_instructeur,
    :etablissement, :pending_corrections,
    { procedure: [:groupe_instructeurs], avis: [:claimant, :expert] },
  ].freeze

  # Associations préchargées pour l'export PDF/zip (PiecesJustificativesService).
  PJ_EXPORT_INCLUDES = [
    :individual, :traitement, :etablissement, :pending_corrections,
    { user: :france_connect_informations, avis: :expert, commentaires: [:instructeur, :expert] },
  ].freeze

  def initialize(dossiers, includes_for_champ: [], includes_for_etablissement: [])
    @dossiers = dossiers
    @includes_for_etablissement = includes_for_etablissement
    @includes_for_champ = includes_for_champ
  end

  # Streame les dossiers dans l'ordre de la relation, par batches adaptatifs.
  # Chaque batch est rechargé avec `includes`, préchargé, yieldé puis relâché :
  # seuls les ids de l'ensemble + un batch de dossiers vivent à la fois.
  # L'ordre est choisi par l'appelant sur la relation (ex: `ordered_for_export`).
  def in_batches(includes:)
    ids = @dossiers.ids
    return if ids.empty?

    ids.each_slice(adaptive_batch_size(ids.size)) do |batch_ids|
      dossiers_by_id = Dossier.where(id: batch_ids).includes(includes).index_by(&:id)

      # Ré-applique l'ordre original
      dossiers = batch_ids.filter_map { dossiers_by_id[it] }
      next if dossiers.empty? # tout le slice supprimé entre le pluck des ids et le rechargement

      load_dossiers(dossiers)
      yield(dossiers)
    end
  end

  def all(pj_template: false)
    dossiers = @dossiers.to_a
    load_dossiers(dossiers, pj_template:)
    dossiers
  end

  def self.load_one(dossier, pj_template: false)
    DossierPreloader.new([dossier]).all(pj_template:).first
  end

  private

  def revisions(pj_template: false)
    @revisions ||= ProcedureRevision.where(id: @dossiers.pluck(:revision_id, :submitted_revision_id).flatten.compact.uniq)
      .includes(procedure: [], revision_types_de_champ: { type_de_champ: pj_template ? { piece_justificative_template_attachment: :blob, notice_explicative_attachment: :blob } : [] })
      .index_by(&:id)
  end

  def load_dossiers(dossiers, pj_template: false)
    to_include = @includes_for_champ.dup

    blob_include = if pj_template
      {
        # avoid N+1 from BlobProcessorConcern:
        attachments: :record,

        # equivalent scope of with_all_variant_records
        variant_records: { image_attachment: :blob },
        preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } },
      }
    else
      {}
    end

    to_include << [
      piece_justificative_file_attachments: {
        blob: blob_include,
      },
    ]

    all_champs = ChampData
      .includes(to_include)
      .where(dossier_id: dossiers)
      .to_a

    champs_by_dossier = all_champs.group_by(&:dossier_id)

    dossiers.each do |dossier|
      load_dossier(dossier, champs_by_dossier[dossier.id] || [], pj_template:)
    end

    load_etablissements(all_champs)
  end

  def load_etablissements(champs)
    to_include = @includes_for_etablissement.dup
    # `champs.siret?` will delegate to type_de_champ; this is not what we want here
    champs_siret = champs.filter { _1.type == 'Champs::SiretChamp' }
    etablissements_by_id = Etablissement.includes(to_include).where(id: champs_siret.map(&:etablissement_id).compact).index_by(&:id)
    champs_siret.each do |champ|
      etablissement = etablissements_by_id[champ.etablissement_id]
      champ.association(:etablissement).target = etablissement
      if etablissement
        etablissement.association(:champ).target = champ
      end
    end
  end

  def load_dossier(dossier, champs, pj_template: false)
    revision = revisions(pj_template:)[dossier.revision_id]
    if revision.present?
      dossier.association(:revision).target = revision
    end
    submitted_revision = revisions[dossier.submitted_revision_id]
    if submitted_revision.present?
      dossier.association(:submitted_revision).target = submitted_revision
    end
    dossier.association(:champ_data).target = champs

    champs.each do |champ|
      champ.association(:dossier).target = dossier

      # assign dossier to attachment records to avoid N+1 in BlobProcessorConcern
      if champ.respond_to?(:piece_justificative_file) && champ.piece_justificative_file.attached?
        champ.piece_justificative_file.attachments.each do |attachment|
          if attachment.blob.attachments.loaded?
            attachment.blob.attachments.each do |blob_attachment|
              if blob_attachment.record.is_a?(ChampData)
                blob_attachment.record.association(:dossier).target = dossier
              end
            end
          end
        end
      end
    end

    # We need to do this because of the check on `Etablissement#champ` in
    # `Etablissement#libelle_for_export`. By assigning `nil` to `target` we mark association
    # as loaded and so the check on `Etablissement#champ` will not trigger n+1 query.
    if dossier.etablissement
      dossier.etablissement.association(:champ).target = nil
    end

    dossier.send(:reset_champs_cache)
  end

  # `count` : nombre de dossiers à batcher. On dimensionne d'après la révision
  # active de la démarche (estimation du nombre de champs par dossier) afin qu'un
  # batch ne charge jamais plus de MAX_CHAMPS_PER_BATCH champs d'un coup.
  def adaptive_batch_size(count)
    return DEFAULT_BATCH_SIZE if count < DEFAULT_BATCH_SIZE

    # Prend un ordre de grandeur de la taille de la démarche
    sample_revision = @dossiers.first.procedure.active_revision
    champs_per_dossier = sample_revision&.types_de_champ&.count.to_i + 1

    # Reste sur un multiple de 100
    ideal_batch_size = (MAX_CHAMPS_PER_BATCH / champs_per_dossier).round(-2)

    # ... avec un minimum de 100
    ideal_batch_size.clamp(100..DEFAULT_BATCH_SIZE)
  end
end
