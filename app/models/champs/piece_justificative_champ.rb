# frozen_string_literal: true

class Champs::PieceJustificativeChamp < ChampData
  FILE_MAX_SIZE = 200.megabytes

  has_many_attached :piece_justificative_file

  validates :piece_justificative_file,
    size: { less_than: FILE_MAX_SIZE },
    if: -> { should_validate_in_current_context? && !type_de_champ.skip_pj_validation }

  validates :piece_justificative_file,
    content_type: -> (_record) { AUTHORIZED_CONTENT_TYPES },
    if: -> { should_validate_in_current_context? && !type_de_champ.skip_content_type_pj_validation }

  validate :validate_dynamic_piece_justificative_rules,
    if: -> { should_validate_in_current_context? && piece_justificative_file.attached? }

  def main_value_name
    :piece_justificative_file
  end

  def search_terms
    # We don’t know how to search inside documents yet
  end

  def external_data_needed_for_validation?
    false
  end

  def has_async_external_data? = ocr_compatible?

  def ocr_result
    return nil if !fetched? || value_json.nil?

    if rib?
      RIB.new(value_json.dig('rib'))
    elsif justificatif_domicile?
      JustificatifDomicile.new(value_json)
    elsif avis_impot?
      AvisImpot.new(value_json)
    end
  end

  private

  def fetch_external_data_later(wait: nil)
    nil # the job is already enqueued by the BlobProcessorJob when the blob is attached
  end

  def ready_for_external_call?
    piece_justificative_file.blobs.present?
  end

  def fetch_external_data
    blob = piece_justificative_file.blobs.first
    OCRService.analyze(blob, nature: type_de_champ.nature)
  end

  def log_content_type_rejection(content_type, allowed_types, attachment)
    Rails.logger.info(
      "[PJ content_type rejected] champ_id=#{id} dossier_id=#{dossier_id} procedure_id=#{procedure.id} " \
      "content_type=#{content_type} filename=#{attachment.filename} " \
      "allowed_types=[#{allowed_types.join(', ')}]"
    )
  end

  def validate_dynamic_piece_justificative_rules
    allowed_types = nil
    max_size = nil

    if type_de_champ.titre_identite?
      allowed_types = type_de_champ.allowed_content_types
      max_size = type_de_champ.max_file_size_bytes
    elsif type_de_champ.ocr_compatible?
      allowed_types = type_de_champ.allowed_content_types
    elsif type_de_champ.pj_limit_formats? && type_de_champ.pj_format_families.present?
      allowed_types = type_de_champ.allowed_content_types
    end

    return if allowed_types.nil? && max_size.nil?

    piece_justificative_file.attachments.each do |attachment|
      if allowed_types.present? && !allowed_types.include?(attachment.content_type)
        log_content_type_rejection(attachment.content_type, allowed_types, attachment)
        errors.add(:piece_justificative_file, :content_type_invalid, content_type: attachment.content_type, count: 1)
      end

      if max_size.present? && attachment.byte_size > max_size
        errors.add(:piece_justificative_file, :file_size_out_of_range, max_size: ActiveSupport::NumberHelper.number_to_human_size(max_size))
      end
    end
  end
end
