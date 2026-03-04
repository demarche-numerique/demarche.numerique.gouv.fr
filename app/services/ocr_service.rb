# frozen_string_literal: true

class OCRService
  include Dry::Monads[:result]
  extend Dry::Monads[:result]

  TWO_D_DOC_ENDPOINT = "/api/v1/workflows/document-barcode-extraction/execute-sync"

  def self.analyze(blob, nature:)
    blob_url = blob.url
    case nature
    when "RIB"                    then analyze_rib(blob_url)
    when "justificatif_domicile"  then analyze_2ddoc(blob_url)
    else raise ArgumentError, "OCRService: unknown nature '#{nature}'"
    end
  end

  private

  def self.analyze_rib(blob_url)
    return not_configured("OCR_SERVICE_URL") if ocr_url.nil?

    json = { "url": blob_url, "hint": { "type": "rib" } }
    headers = { 'X-Remote-File': blob_url } # needed for logging

    API::Client.new.call(url: ocr_url, method: :post, headers:, json:, timeout: 31)
      .fmap { |ok| { value_json: ok.body } } # store directly in value_json without transformation
      .or { to_retryable_failure(it) }
  end

  def self.analyze_2ddoc(blob_url)
    return not_configured('DOCUMENT_IA_URL') if document_ia_url.nil?

    url = document_ia_url + TWO_D_DOC_ENDPOINT
    headers = { 'X-API-KEY': ENV.fetch('DOCUMENT_IA_KEY') }
    body = { file_url: blob_url }

    API::Client.new.call(url:, headers:, method: :post, body:)
      .fmap { |ok| { data: ok.body, value_json: extract_2ddoc(ok.body) } }
      .or { to_retryable_failure(it) }
  end

  def self.extract_2ddoc(body)
    barcode = body
      .dig(:data, :result, :barcodes)
      &.find { it[:type] == '2D_DOC' && it[:is_valid] } # take the first valid 2ddoc

    return nil if barcode.nil?

    ddoc = barcode[:raw_data]
    return nil if ddoc.nil? || !justif_domicile?(ddoc)

    fields = ddoc[:fields]
    # format : '2026-01-02'
    issue_date = barcode[:issue_date]&.then { Date.strptime(it, '%Y-%m-%d') }

    attr = {
      beneficiary: fields[:"10"]&.tr('/', ' '),
      address: fields[:"22"],
      postal_code: fields[:"24"],
      locality: fields[:"25"],
      country: fields[:"26"],
      issue_date:,
      two_ddoc: true,
    }

    # force parsing to ensure compat
    JustificatifDomicile.new(attr).attributes
  end

  def self.justif_domicile?(ddoc) = ddoc[:doc_type].in?(['00', '01', '02'])

  def self.ocr_url = ENV.fetch("OCR_SERVICE_URL", nil)
  def self.document_ia_url = ENV.fetch("DOCUMENT_IA_URL", nil)

  def self.not_configured(message)
    Failure(retryable: false, error: StandardError.new("#{message} not configured"))
  end

  def self.to_retryable_failure(data)
    case data
    in code:, error:
      Failure(retryable: false, error:, code:)
    else
      Failure(retryable: false, error: StandardError.new('Unknown error'))
    end
  end
end
