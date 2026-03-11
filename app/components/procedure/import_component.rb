# frozen_string_literal: true

class Procedure::ImportComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def csv_max_size
    CsvParsingConcern::CSV_MAX_SIZE
  end

  def groupes_template_path
    if @procedure.routing_enabled?
      '/csv/import-groupe-test.csv'
    else
      '/csv/import-instructeurs-test.csv'
    end
  end

  def groupes_template_detail
    template_detail_for(groupes_template_path)
  end

  def contact_informations_template_path
    '/csv/import-contact-informations-test.csv'
  end

  def contact_informations_template_detail
    template_detail_for(contact_informations_template_path)
  end

  private

  def template_detail_for(path)
    file = Rails.public_path.join(path.delete_prefix('/')).open
    "#{File.extname(file.to_path).upcase.delete_prefix('.')} – #{number_to_human_size(file.size)}"
  end
end
