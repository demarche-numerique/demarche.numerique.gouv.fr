# frozen_string_literal: true

class DossierPreloader
  DEFAULT_BATCH_SIZE = 2000
  MAX_CHAMPS_PER_BATCH = 140_000

  def initialize(dossiers, includes_for_champ: [], includes_for_etablissement: [])
    @dossiers = dossiers
    @includes_for_etablissement = includes_for_etablissement
    @includes_for_champ = includes_for_champ
  end

  def in_batches
    dossiers = @dossiers.to_a
    batch_size = adaptive_batch_size(dossiers)
    dossiers.each_slice(batch_size) { load_dossiers(it) }
    dossiers
  end

  def in_batches_with_block(&block)
    @dossiers.in_batches(of: adaptive_batch_size(@dossiers)) do |batch|
      data = Dossier.where(id: batch.ids).includes(:individual, :traitement, :etablissement, :pending_corrections, user: :france_connect_informations, avis: :expert, commentaires: [:instructeur, :expert])

      dossiers = data.to_a
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

    all_champs = Champ
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
    dossier.association(:champs).target = champs

    champs.each do |champ|
      champ.association(:dossier).target = dossier

      # assign dossier to attachment records to avoid N+1 in BlobProcessorConcern
      if champ.respond_to?(:piece_justificative_file) && champ.piece_justificative_file.attached?
        champ.piece_justificative_file.attachments.each do |attachment|
          if attachment.blob.attachments.loaded?
            attachment.blob.attachments.each do |blob_attachment|
              if blob_attachment.record.is_a?(Champ)
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

  def adaptive_batch_size(dossiers)
    return DEFAULT_BATCH_SIZE if dossiers.count < DEFAULT_BATCH_SIZE

    # Prend un ordre de grandeur de la taille de la démarche
    champs_per_dossier = dossiers.last.revision.types_de_champ.count + 1

    # Reste sur un multiple de 100
    ideal_batch_size = (MAX_CHAMPS_PER_BATCH / champs_per_dossier).round(-2)

    # ... avec un minimum de 100
    ideal_batch_size.clamp(100..DEFAULT_BATCH_SIZE)
  end
end
