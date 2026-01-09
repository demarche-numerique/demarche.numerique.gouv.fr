# frozen_string_literal: true

require Rails.root.join("lib", "tasks", "task_helper")

namespace :stats do
  def add_procedure_stat(stats_array, feature_name, scope, total_count, total_dossiers_all_procedures)
    count = scope.count
    percentage = total_count > 0 ? ((count.to_f / total_count) * 100).round(2) : 0

    # Récupération de 3 IDs d’exemple distincts
    sample_ids = scope.distinct.limit(3).pluck(:id)

    # Calcul de la somme des dossiers
    procedures = scope.distinct

    total_dossiers = if procedures.any?
      ActiveRecord::Base.connection.execute(<<~SQL.squish).values.flatten.first
        SELECT sum(estimated_dossiers_count) from procedures where procedures.id IN (#{procedures.ids.join(',')});
      SQL
    else
      0
    end

    # Calcul du pourcentage de dossiers concernés
    dossiers_percentage = total_dossiers_all_procedures > 0 ? ((total_dossiers.to_f / total_dossiers_all_procedures) * 100).round(2) : 0

    stats_array << {
      feature: feature_name,
      count: count,
      percentage: percentage,
      sample_ids: sample_ids,
      total_dossiers: total_dossiers,
      dossiers_percentage: dossiers_percentage,
    }

    rake_puts "#{feature_name}: #{count} démarches (#{percentage}%) - #{total_dossiers} dossiers (#{dossiers_percentage}%)"
  end

  def add_procedure_stat_with_instructeurs(stats_array, feature_name, scope, total_count)
    count = scope.count
    percentage = total_count > 0 ? ((count.to_f / total_count) * 100).round(2) : 0

    # Récupération de 3 IDs d’exemple distincts
    sample_ids = scope.distinct.limit(3).pluck(:id)

    # Calcul du nombre d’instructeurs ayant accès aux export_templates (avant fonctionnalité de partage des modèles)
    total_instructeurs = scope.joins(export_templates: { groupe_instructeur: :instructeurs })
      .select('instructeurs.id')
      .distinct
      .count

    {
      feature: feature_name,
      count: count,
      percentage: percentage,
      sample_ids: sample_ids,
      total_instructeurs: total_instructeurs,
    }
  end
  desc <<~EOD
    Génère des statistiques d’utilisation des fonctionnalités des démarches publiées ou closes
    au cours des 2 dernières années. Génère un fichier CSV avec les résultats.
  EOD
  task procedure_features: :environment do
    rake_puts "Génération des statistiques de fonctionnalités des démarches..."

    # Scope de base : démarches publiées ou closes dans les 2 dernières années
    # basé sur la date de publication de la révision publiée
    base_scope = Procedure.publiees_ou_closes
      .joins("INNER JOIN procedure_revisions ON procedure_revisions.id = procedures.published_revision_id")
      .where(procedure_revisions: { published_at: 2.years.ago.. })
      .includes(:labels, :attestation_template, :attestation_templates_v2,
                :dossier_submitted_messages, :revisions, :published_revision)

    procedure_ids = base_scope.distinct.pluck(:id)
    total_procedures = procedure_ids.count
    total_dossiers_all_procedures = Procedure.where(id: procedure_ids).sum(:estimated_dossiers_count)

    rake_puts "Scope total : #{total_procedures} démarches"
    rake_puts "Total dossiers : #{total_dossiers_all_procedures} dossiers"

    stats = []

    # 1. Démarches pour personnes physiques
    individual_procedures = base_scope.where(for_individual: true)
    add_procedure_stat(stats, "Personnes physiques", individual_procedures, total_procedures, total_dossiers_all_procedures)

    # 2. Démarches pour personnes morales
    organization_procedures = base_scope.where(for_individual: false)
    add_procedure_stat(stats, "Personnes morales", organization_procedures, total_procedures, total_dossiers_all_procedures)

    # 3. Règles d’inéligibilité activées
    ineligibilite_procedures = base_scope.joins(:published_revision)
      .where(procedure_revisions: { ineligibilite_enabled: true })
      .distinct
    add_procedure_stat(stats, "Règles d’inéligibilité activées", ineligibilite_procedures, total_procedures, total_dossiers_all_procedures)

    # 4. Accusé lecture activé
    accuse_lecture_procedures = base_scope.where(accuse_lecture: true)
    add_procedure_stat(stats, "Accusé lecture activé", accuse_lecture_procedures, total_procedures, total_dossiers_all_procedures)

    # 5. Labels personnalisés (différents des labels par défaut)
    custom_labels_procedures = base_scope.joins(:labels)
      .where.not(labels: { name: Label::GENERIC_LABELS.map { |l| l[:name] } })
      .distinct
    add_procedure_stat(stats, "Labels personnalisés", custom_labels_procedures, total_procedures, total_dossiers_all_procedures)

    # 6. Prise de RDV activé
    rdv_procedures = base_scope.where(rdv_enabled: true)
    add_procedure_stat(stats, "Prise de RDV activé", rdv_procedures, total_procedures, total_dossiers_all_procedures)

    # 7. Code pour le bouton mon avis
    monavis_procedures = base_scope.where.not(monavis_embed: [nil, ''])
    add_procedure_stat(stats, "Bouton MonAvis configuré", monavis_procedures, total_procedures, total_dossiers_all_procedures)

    # 8. SVA/SVR activé
    sva_svr_procedures = base_scope.where.not(sva_svr: [nil, {}])
    add_procedure_stat(stats, "SVA/SVR activé", sva_svr_procedures, total_procedures, total_dossiers_all_procedures)

    # 9. Personnalisation du message fin de dépôt
    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute("SET LOCAL statement_timeout = '10min'")
      custom_message_procedures = base_scope.joins(:dossier_submitted_messages)
        .where.not(dossier_submitted_messages: { message_on_submit_by_usager: [nil, ''] })
        .distinct
      add_procedure_stat(stats, "Message fin de dépôt personnalisé", custom_message_procedures, total_procedures, total_dossiers_all_procedures)
    end

    # 10. API entreprise avec jeton personnalisé
    api_entreprise_procedures = base_scope.where.not(api_entreprise_token: [nil, ''])
    add_procedure_stat(stats, "API Entreprise avec jeton personnalisé", api_entreprise_procedures, total_procedures, total_dossiers_all_procedures)

    # 11. Démarches déclaratives - en instruction
    declarative_instruction_procedures = base_scope.where(declarative_with_state: 'en_instruction')
    add_procedure_stat(stats, "Démarches déclaratives (en instruction)", declarative_instruction_procedures, total_procedures, total_dossiers_all_procedures)

    # 12. Démarches déclaratives - accepté
    declarative_accepte_procedures = base_scope.where(declarative_with_state: 'accepte')
    add_procedure_stat(stats, "Démarches déclaratives (accepté)", declarative_accepte_procedures, total_procedures, total_dossiers_all_procedures)

    # 13. Date de clôture renseignée à l’avance
    auto_archive_procedures = base_scope.where.not(auto_archive_on: nil)
    add_procedure_stat(stats, "Date de clôture programmée", auto_archive_procedures, total_procedures, total_dossiers_all_procedures)

    # 14. Démarches avec routage personnalisé
    routing_procedures = base_scope.where(routing_enabled: true)
    add_procedure_stat(stats, "Routage activé", routing_procedures, total_procedures, total_dossiers_all_procedures)

    # 15. Démarches avec attestation v1
    attestation_v1_procedures = base_scope.joins(:attestation_template_v1)
      .where(attestation_templates: { activated: true })
      .distinct
    add_procedure_stat(stats, "Attestation v1", attestation_v1_procedures, total_procedures, total_dossiers_all_procedures)

    # 16. Démarches avec attestation v2
    attestation_v2_procedures = base_scope.joins(:attestation_templates_v2)
      .where(attestation_templates: { state: 'published' })
      .distinct
    add_procedure_stat(stats, "Attestation v2", attestation_v2_procedures, total_procedures, total_dossiers_all_procedures)

    # 17. Démarches avec attestation (total)
    attestation_total_procedures_ids = (attestation_v1_procedures.pluck(:id) + attestation_v2_procedures.pluck(:id)).uniq
    attestation_total_procedures = base_scope.where(id: attestation_total_procedures_ids)
    add_procedure_stat(stats, "Attestation (total)", attestation_total_procedures, total_procedures, total_dossiers_all_procedures)

    # 18. Démarches avec annotations privées
    private_annotation_ids = ActiveRecord::Base.connection.execute(<<~SQL.squish).values.flatten
      SELECT DISTINCT procedures.id
      FROM procedures
      INNER JOIN procedure_revisions ON procedure_revisions.id = procedures.published_revision_id
      INNER JOIN procedure_revision_types_de_champ ON procedure_revision_types_de_champ.revision_id = procedure_revisions.id
      INNER JOIN types_de_champ ON types_de_champ.id = procedure_revision_types_de_champ.type_de_champ_id
      WHERE procedures.hidden_at IS NULL
        AND procedures.aasm_state IN ('publiee', 'close', 'depubliee')
        AND procedure_revisions.published_at >= '#{2.years.ago.to_fs(:db)}'
        AND types_de_champ.private = true
    SQL
    private_annotations_procedures = base_scope.where(id: private_annotation_ids)
    add_procedure_stat(stats, "Avec annotations privées", private_annotations_procedures, total_procedures, total_dossiers_all_procedures)

    # 21. Démarches avec champs conditionnels
    conditional_ids = ActiveRecord::Base.connection.execute(<<~SQL.squish).values.flatten
      SELECT DISTINCT procedures.id
      FROM procedures
      INNER JOIN procedure_revisions ON procedure_revisions.id = procedures.published_revision_id
      INNER JOIN procedure_revision_types_de_champ ON procedure_revision_types_de_champ.revision_id = procedure_revisions.id
      INNER JOIN types_de_champ ON types_de_champ.id = procedure_revision_types_de_champ.type_de_champ_id
      WHERE procedures.hidden_at IS NULL
        AND procedures.aasm_state IN ('publiee', 'close', 'depubliee')
        AND procedure_revisions.published_at >= '#{2.years.ago.to_fs(:db)}'
        AND types_de_champ.condition IS NOT NULL
    SQL
    conditional_procedures = base_scope.where(id: conditional_ids)
    add_procedure_stat(stats, "Avec champs conditionnels", conditional_procedures, total_procedures, total_dossiers_all_procedures)

    # 22. Démarches avec avis demandés
    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute("SET LOCAL statement_timeout = '10min'")
      avis_procedures = base_scope.joins(:dossiers)
        .joins('INNER JOIN avis ON avis.dossier_id = dossiers.id')
        .distinct

      add_procedure_stat(stats, "Avec avis demandés", avis_procedures, total_procedures, total_dossiers_all_procedures)
    end

    # 23. Emails personnalisés
    email_stats = [
      ["Email construction personnalisé", :initiated_mail],
      ["Email instruction personnalisé", :received_mail],
      ["Email acceptation personnalisé", :closed_mail],
      ["Email refus personnalisé", :refused_mail],
      ["Email classé sans suite personnalisé", :without_continuation_mail],
      ["Email ré-instruction personnalisé", :re_instructed_mail],
    ]

    email_stats.each do |label, association|
      table_name = case association
      when :initiated_mail then 'initiated_mails'
      when :received_mail then 'received_mails'
      when :closed_mail then 'closed_mails'
      when :refused_mail then 'refused_mails'
      when :without_continuation_mail then 'without_continuation_mails'
      when :re_instructed_mail then 're_instructed_mails'
      end

      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute("SET LOCAL statement_timeout = '2min'")

        customized_email_procedures = base_scope.joins(association)
          .where.not(table_name => { updated_at: nil })
          .distinct
        add_procedure_stat(stats, label, customized_email_procedures, total_procedures, total_dossiers_all_procedures)
      end
    end

    # 29. Démarches avec modèles d’export (traité séparément)
    export_templates_procedures = base_scope.joins(:export_templates).distinct
    export_templates_stat = add_procedure_stat_with_instructeurs(stats, "Avec modèles d’export", export_templates_procedures, total_procedures)

    rake_puts "Avec modèles d’export (hors partage): #{export_templates_stat[:count]} démarches (#{export_templates_stat[:percentage]}%) - #{export_templates_stat[:total_instructeurs]} instructeurs"

    # 30. Démarches issues de clones
    cloned_procedures = base_scope.where(cloned_from_library: true)
    add_procedure_stat(stats, "Issues de clones", cloned_procedures, total_procedures, total_dossiers_all_procedures)

    # === STATISTIQUES PAR TYPE DE CHAMP ===

    rake_puts "\n=== Génération des statistiques par type de champ ==="

    # Récupération des stats par type de champ sur les champs publics (parent = null uniquement)
    # Utilisons une approche en 2 étapes pour éviter les problèmes d’attributs manquants
    type_champ_data = ActiveRecord::Base.connection.execute(<<~SQL.squish).to_a
      SELECT
        type_champ,
        COUNT(*) as nb_procedures,
        SUM(estimated_dossiers_count) as nb_dossiers
      FROM (
        SELECT DISTINCT
          types_de_champ.type_champ,
          procedures.id,
          procedures.estimated_dossiers_count
        FROM types_de_champ
        INNER JOIN procedure_revision_types_de_champ ON procedure_revision_types_de_champ.type_de_champ_id = types_de_champ.id
        INNER JOIN procedure_revisions ON procedure_revisions.id = procedure_revision_types_de_champ.revision_id
        INNER JOIN procedures ON procedures.id = procedure_revisions.procedure_id
        WHERE procedure_revision_types_de_champ.parent_id IS NULL
          AND types_de_champ.private = false
          AND procedure_revisions.published_at >= '#{2.years.ago.to_fs(:db)}'
          AND procedures.hidden_at IS NULL
          AND procedures.aasm_state IN ('publiee', 'close', 'depubliee')
          AND procedures.published_revision_id = procedure_revisions.id
      ) as unique_procedures
      GROUP BY type_champ
      ORDER BY nb_procedures DESC, nb_dossiers DESC
    SQL

    type_champ_results = []

    type_champ_data.each do |row|
      nb_procedures = row['nb_procedures'].to_i
      nb_dossiers = row['nb_dossiers'].to_i
      percentage_procedures = total_procedures > 0 ? ((nb_procedures.to_f / total_procedures) * 100).round(2) : 0
      percentage_dossiers = total_dossiers_all_procedures > 0 ? ((nb_dossiers.to_f / total_dossiers_all_procedures) * 100).round(2) : 0

      type_champ = I18n.t(row['type_champ'], scope: "activerecord.attributes.type_de_champ.type_champs")

      type_champ_results << {
        type_champ:,
        nb_procedures: nb_procedures,
        nb_dossiers: nb_dossiers,
        percentage_procedures: percentage_procedures,
        percentage_dossiers: percentage_dossiers,
      }

      rake_puts "#{type_champ}: #{nb_procedures} démarches (#{percentage_procedures}%) - #{nb_dossiers} dossiers (#{percentage_dossiers}%)"
    end

    rake_puts "#{type_champ_results.count} types de champs différents trouvés"

    # === STATISTIQUES SUR LES DOSSIERS ===

    # Scope de base pour les dossiers liés aux procédures du scope
    dossiers_base_scope = Dossier.joins(revision: :procedure)
      .where(procedure_revisions: { published_at: 2.years.ago.. })
      .where(procedures: { hidden_at: nil, aasm_state: ['publiee', 'close', 'depubliee'] })

    # 31. Dossiers avec messages envoyés par les instructeurs
    dossiers_with_instructeur_messages = dossiers_base_scope
      .joins(:commentaires)
      .where.not(commentaires: { instructeur_id: nil })
      .distinct
      .count

    rake_puts "Dossiers avec messages d’instructeurs: #{dossiers_with_instructeur_messages}"

    # 32. Dossiers avec messages envoyés par les usagers (ni instructeur, ni expert, ni système)
    system_emails = Commentaire::SYSTEM_EMAILS
    system_conditions = system_emails.map { |email| "commentaires.email LIKE '%#{email}%'" }.join(' OR ')

    dossiers_with_usager_messages = dossiers_base_scope
      .joins(:commentaires)
      .where(commentaires: { instructeur_id: nil, expert_id: nil })
      .where("NOT (#{system_conditions})")
      .distinct
      .count

    rake_puts "Dossiers avec messages d’usagers: #{dossiers_with_usager_messages}"

    # 33. Dossiers avec des labels
    dossiers_with_labels = dossiers_base_scope
      .joins(:labels)
      .distinct
      .count

    rake_puts "Dossiers avec labels: #{dossiers_with_labels}"

    # Génération du fichier CSV
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "procedure_features_stats_#{timestamp}.csv"
    filepath = Rails.root.join("tmp", filename)

    CSV.open(filepath, 'wb', headers: true) do |csv|
      csv << ['Fonctionnalité', 'Nombre de démarches', 'Pourcentage démarches', 'Total dossiers', 'Pourcentage dossiers', 'Exemples d’IDs']

      stats.each do |stat|
        csv << [
          stat[:feature],
          stat[:count],
          stat[:percentage],
          stat[:total_dossiers],
          stat[:dossiers_percentage],
          stat[:sample_ids].join(', '),
        ]
      end

      # Ajouter les statistiques par type de champ
      csv << []
      csv << ['=== STATISTIQUES PAR TYPE DE CHAMP ===']
      csv << ['Type de champ', 'Nombre de démarches', 'Pourcentage démarches', 'Nombre de dossiers', 'Pourcentage dossiers', '']

      type_champ_results.each do |result|
        csv << [
          result[:type_champ],
          result[:nb_procedures],
          result[:percentage_procedures],
          result[:nb_dossiers],
          result[:percentage_dossiers],
          '',
        ]
      end

      # Ajouter les statistiques sur les dossiers
      csv << []
      csv << ['=== STATISTIQUES DOSSIERS ===']
      dossiers_percentage_instructeur = total_dossiers_all_procedures > 0 ? ((dossiers_with_instructeur_messages.to_f / total_dossiers_all_procedures) * 100).round(2) : 0
      dossiers_percentage_usager = total_dossiers_all_procedures > 0 ? ((dossiers_with_usager_messages.to_f / total_dossiers_all_procedures) * 100).round(2) : 0
      dossiers_percentage_labels = total_dossiers_all_procedures > 0 ? ((dossiers_with_labels.to_f / total_dossiers_all_procedures) * 100).round(2) : 0

      csv << ['Dossiers avec messages d’instructeurs', dossiers_with_instructeur_messages, dossiers_percentage_instructeur, '', '', '']
      csv << ['Dossiers avec messages d’usagers', dossiers_with_usager_messages, dossiers_percentage_usager, '', '', '']
      csv << ['Dossiers avec labels', dossiers_with_labels, dossiers_percentage_labels, '', '', '']

      # Ajouter les statistiques export_templates séparément
      csv << []
      csv << ['=== STATISTIQUES INSTRUCTEURS ===']
      csv << ['Fonctionnalité', 'Nombre de démarches', 'Pourcentage démarches', 'Nombre d’instructeurs', '', 'Exemples d’IDs']
      csv << [
        export_templates_stat[:feature],
        export_templates_stat[:count],
        export_templates_stat[:percentage],
        export_templates_stat[:total_instructeurs],
        nil,
        export_templates_stat[:sample_ids].join(', '),
      ]
    end

    rake_puts "\n=== STATISTIQUES DOSSIERS ==="
    rake_puts "Dossiers avec messages d’instructeurs: #{dossiers_with_instructeur_messages} (#{total_dossiers_all_procedures > 0 ? ((dossiers_with_instructeur_messages.to_f / total_dossiers_all_procedures) * 100).round(2) : 0}%)"
    rake_puts "Dossiers avec messages d’usagers: #{dossiers_with_usager_messages} (#{total_dossiers_all_procedures > 0 ? ((dossiers_with_usager_messages.to_f / total_dossiers_all_procedures) * 100).round(2) : 0}%)"
    rake_puts "Dossiers avec labels: #{dossiers_with_labels} (#{total_dossiers_all_procedures > 0 ? ((dossiers_with_labels.to_f / total_dossiers_all_procedures) * 100).round(2) : 0}%)"

    rake_puts "Fichier CSV généré : #{filepath}"
  end
end
