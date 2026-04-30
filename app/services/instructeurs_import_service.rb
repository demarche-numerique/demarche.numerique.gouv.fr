# frozen_string_literal: true

class InstructeursImportService
  def self.import_groupes(procedure, groupes_emails, overwrite: false, administrateur: nil)
    groupes_emails, error_groupe_emails = groupes_emails.partition { _1['groupe'].present? }

    groupes_emails = groupes_emails.map do
      {
        groupe: _1['groupe'].strip,
        email: _1['email'].present? ? EmailSanitizableConcern::EmailSanitizer.sanitize(_1['email']) : nil,
      }
    end
    errors = error_groupe_emails.map { _1['email'] }.uniq
    target_labels = groupes_emails.map { _1[:groupe] }.uniq

    missing_labels = target_labels - procedure.groupe_instructeurs.pluck(:label)

    if missing_labels.present?
      created_at = Time.zone.now
      GroupeInstructeur.create!(missing_labels.map { |label| { procedure_id: procedure.id, label:, created_at:, updated_at: created_at } })
      procedure.toggle_routing
    end

    emails_in_groupe = groupes_emails
      .group_by { _1[:groupe] }
      .transform_values { |groupes_emails| groupes_emails.map { _1[:email] }.uniq }
    emails_in_groupe.default = []

    target_groupes = procedure
      .groupe_instructeurs
      .where(label: target_labels)
      .index_with { emails_in_groupe[_1.label] }

    groupes_by_instructeur = Hash.new { |h, k| h[k] = [] }
    removed_groupes_by_instructeur = Hash.new { |h, k| h[k] = [] }
    invalid_emails_per_groupe = {}

    target_groupes.each do |groupe_instructeur, emails|
      added_instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails:)

      added_instructeurs.each do |instructeur|
        groupes_by_instructeur[instructeur] << groupe_instructeur
      end

      invalid_emails_per_groupe[groupe_instructeur] = invalid_emails
      errors << invalid_emails
    end

    preserved_groupes = []

    if overwrite
      # For groups in the CSV : list the instructors absent from CSV and remove them
      target_groupes.each do |groupe_instructeur, emails_in_csv|
        valid_emails = emails_in_csv - (invalid_emails_per_groupe[groupe_instructeur] || [])

        remove_instructeurs_not_in_csv(groupe_instructeur, valid_emails).each do |instructeur|
          removed_groupes_by_instructeur[instructeur] << groupe_instructeur
        end
      end

      # For groups absent from CSV : remove all instructors, then delete group if possible.
      # If the group has dossiers, assign the administrateur as fallback instructor.
      procedure.groupe_instructeurs.where.not(label: target_labels).find_each do |groupe|
        groupe.instructeurs.each do |instructeur|
          groupe.remove(instructeur)
          removed_groupes_by_instructeur[instructeur] << groupe
        end

        if groupe.dossiers.any? && administrateur&.instructeur
          groupe.add(administrateur.instructeur)
          preserved_groupes << groupe.label
        elsif groupe.can_delete?
          groupe.destroy
        end
      end

      if procedure.groupe_instructeurs.active.one?
        remaining_group = procedure.groupe_instructeurs.active.first
        procedure.toggle_routing
        procedure.update!(routing_alert: false, defaut_groupe_instructeur: remaining_group)
        remaining_group.update!(
          routing_rule: nil,
          label: GroupeInstructeur::DEFAUT_LABEL,
          closed: false,
          contact_information: nil
        )
      end
    end

    [groupes_by_instructeur, errors.flatten, preserved_groupes, removed_groupes_by_instructeur]
  end

  def self.import_instructeurs(procedure, emails, overwrite: false)
    instructeurs_emails = emails
      .map { _1["email"] }
      .compact
      .map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1) }

    groupe_instructeur = procedure.defaut_groupe_instructeur

    added_instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails: instructeurs_emails)

    removed_instructeurs = if overwrite
      remove_instructeurs_not_in_csv(groupe_instructeur, instructeurs_emails - invalid_emails)
    else
      []
    end

    [added_instructeurs, invalid_emails, removed_instructeurs]
  end

  private

  def self.remove_instructeurs_not_in_csv(groupe_instructeur, valid_emails)
    return [] if valid_emails.empty?

    instructeurs_to_remove = groupe_instructeur.instructeurs.reload.reject { _1.email.in?(valid_emails) }
    instructeurs_to_remove.each { groupe_instructeur.remove(_1) }
    instructeurs_to_remove
  end
end
