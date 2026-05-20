# frozen_string_literal: true

class Cron::DiscardedDossiersDeletionBaseJob < Cron::CronJob
  BATCH_LIMIT = 100

  # Classe abstraite : empêche `rake jobs:schedule` de tenter d'enregistrer
  # cette base (qui n'a pas de schedule_expression) dans Sidekiq Cron.
  # Les sous-classes concrètes héritent : elles sont schedulable dès que
  # schedule_expression est défini.
  def self.schedulable?
    schedule_expression.present? && super
  end

  def perform
    count = 0
    start = Time.current
    heap_before = GC.stat(:heap_live_slots)
    rss_before = current_rss_mb

    scope.find_each(batch_size: BATCH_LIMIT) do |dossier|
      dossier.purge_discarded
      count += 1
      break if count >= BATCH_LIMIT
    end

    self.class.perform_later if count >= BATCH_LIMIT && scope.exists?
  ensure
    Rails.logger.info(
      "[#{self.class.name}] purged=#{count} " \
      "duration=#{(Time.current - start).round(2)}s " \
      "heap_live_delta=#{GC.stat(:heap_live_slots) - heap_before} " \
      "rss=#{rss_before}->#{current_rss_mb}MB"
    )
  end

  private

  def scope = raise NotImplementedError

  # RSS en MB lu depuis /proc/self/status (Linux). Renvoie nil sur les
  # plateformes sans procfs (macOS dev) — le log dégrade proprement.
  def current_rss_mb
    return nil if !File.exist?('/proc/self/status')

    kb = File.read('/proc/self/status')[/^VmRSS:\s+(\d+)/, 1]
    kb.to_i / 1024 if kb
  end
end
