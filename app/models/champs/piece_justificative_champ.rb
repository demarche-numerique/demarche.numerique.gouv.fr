# frozen_string_literal: true

class Champs::PieceJustificativeChamp < Champ
  FILE_MAX_SIZE = 200.megabytes

  has_many_attached :piece_justificative_file

  validates :piece_justificative_file,
    size: { less_than: FILE_MAX_SIZE },
    if: -> { validate_champ_value? && !type_de_champ.skip_pj_validation }

  validates :piece_justificative_file,
    content_type: AUTHORIZED_CONTENT_TYPES,
    if: -> { validate_champ_value? && !type_de_champ.skip_content_type_pj_validation }

  validate :validate_dynamic_piece_justificative_rules,
    if: -> { validate_champ_value? && piece_justificative_file.attached? }

  def main_value_name
    :piece_justificative_file
  end

  def search_terms
    # We don’t know how to search inside documents yet
  end

  def external_data_needed_for_validation?
    false
  end

  def has_async_external_data?
    RIB?
  end

  private

  def fetch_external_data_later(wait: nil)
    nil # the job is already enqueued by the ImageProcessorJob when the blob is attached
  end

  def ready_for_external_call?
    piece_justificative_file.blobs.present?
  end

  def fetch_external_data
    blob = piece_justificative_file.blobs.first
    OCRService.analyze(blob)
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

    if type_de_champ.titre_identite_nature?
      allowed_types = type_de_champ.allowed_content_types
      max_size = type_de_champ.max_file_size_bytes
    elsif type_de_champ.RIB?
      allowed_types = type_de_champ.allowed_content_types
    elsif type_de_champ.pj_limit_formats? && type_de_champ.pj_format_families.present?
      allowed_types = type_de_champ.allowed_content_types
    end

    return if allowed_types.nil? && max_size.nil?

    piece_justificative_file.attachments.each do |attachment|
      if allowed_types.present? && !allowed_types.include?(attachment.content_type)
        log_content_type_rejection(attachment.content_type, allowed_types, attachment)
        errors.add(:piece_justificative_file, :content_type_invalid, content_type: attachment.content_type)
      end

      if max_size.present? && attachment.byte_size > max_size
        errors.add(:piece_justificative_file, :file_size_out_of_range, max_size: ActiveSupport::NumberHelper.number_to_human_size(max_size))
      end
    end
  end
end
