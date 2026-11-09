# frozen_string_literal: true

module Maintenance
  # Purges the champ attachments whose champ no longer exists. Nothing displays
  # them any more, and their files outlive the dossier retention period.
  #
  # Looking for them over the whole table exceeds the statement timeout, so the
  # task walks the primary key in fixed ranges, each one costing a bounded
  # anti-join on the champs primary key.
  class T20261109purgeChampOrphanAttachmentsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    RANGE_SIZE = 50_000

    # The ranges start at a fixed origin: MaintenanceTasks resumes an array
    # collection by index, so a moving minimum would shift them on resume.
    def collection
      (1..ActiveStorage::Attachment.maximum(:id).to_i).step(RANGE_SIZE).to_a
    end

    def process(from)
      ActiveStorage::Attachment
        .where(id: from...(from + RANGE_SIZE), record_type: 'Champ')
        .where.not(ChampData.where('champs.id = active_storage_attachments.record_id').arel.exists)
        .find_each(&:purge_later)
    end
  end
end
