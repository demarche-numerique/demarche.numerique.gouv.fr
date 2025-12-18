# frozen_string_literal: true

class InstructeursImportService
  def self.import_groupes(procedure, groupes_emails)
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

    target_groupes.each do |groupe_instructeur, emails|
      added_instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails:)

      added_instructeurs.each do |instructeur|
        groupes_by_instructeur[instructeur] << groupe_instructeur
      end

      errors << invalid_emails
    end

    [groupes_by_instructeur, errors.flatten]
  end

  def self.import_instructeurs(procedure, emails)
    instructeurs_emails = emails
      .map { _1["email"] }
      .compact
      .map { EmailSanitizableConcern::EmailSanitizer.sanitize(_1) }

    groupe_instructeur = procedure.defaut_groupe_instructeur

    instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails: instructeurs_emails)

    [instructeurs, invalid_emails]
  end
end
