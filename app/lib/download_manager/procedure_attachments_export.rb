# frozen_string_literal: true

module DownloadManager
  class ProcedureAttachmentsExport
    delegate :destination, to: :@queue

    attr_reader :queue
    attr_accessor :errors

    def initialize(procedure, attachments, destination)
      @procedure = procedure
      @errors = {}
      @reported_error_classes = Set.new
      @queue = ParallelDownloadQueue.new(attachments, destination)
      @queue.on_error = proc do |attachment, path, error|
        errors[path] = [attachment, path]
        Rails.logger.error("Fail to download filename #{path} in procedure##{@procedure.id}, reason: #{error}")

        # `on_error` gets an HTTP status code for a failed download (expected, and
        # retried) but an exception for anything else — a traversing path from a
        # malformed template, a filename ActiveStorage did not sanitize... Those are
        # bugs, so alert rather than only log.
        #
        # Once per class per export: a bad template makes *every* path fail the same
        # way, and we would otherwise emit one Sentry event per attachment for a
        # single root cause.
        if error.is_a?(Exception) && @reported_error_classes.add?(error.class)
          Sentry.capture_exception(error, tags: { procedure: @procedure.id })
        end
      end
    end

    def download_all(attempt_left: 1)
      @queue.download_all
      if !errors.empty? && attempt_left.positive?
        retryable_queue = self.class.new(@procedure, errors.values, destination)
        retryable_queue.download_all(attempt_left: 0)
        retryable_queue.write_report if !retryable_queue.errors.empty?
      end
    end

    def write_report
      manifest_path = File.join(destination, '-LISTE-DES-FICHIERS-EN-ERREURS.txt')
      manifest_content = errors.map do |file_basename, _failed|
                                                      "Impossible de récupérer le fichier #{file_basename}"
                                                    end
        .join("\n")
      File.write(manifest_path, manifest_content)
    end
  end
end
