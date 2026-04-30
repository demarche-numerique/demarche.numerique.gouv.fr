# frozen_string_literal: true

module ProcedureCloneConcern
  extend ActiveSupport::Concern

  # What to do when an attribute is added to Procedure model ? Follow these steps:
  # A) 3 options are available:
  #   1) To keep the value in the cloned procedure -> nothing to do
  #   2) To nullify or reset the value in the cloned procedure -> make the change in #initialize_clone_defaults
  #   3) To let the admin choose to keep it or not -> add it to clone settings, following the example of commit 1138ab1 (PR #11644)
  # B) Add the attribute to MANAGED_ATTRIBUTES to make the tests pass

  MANAGED_ATTRIBUTES = [
    'id',
    'libelle',
    'description',
    'organisation',
    'created_at',
    'updated_at',
    'euro_flag',
    'lien_site_web',
    'lien_notice',
    'for_individual',
    'auto_archive_on',
    'published_at',
    'hidden_at',
    'whitelisted_at',
    'ask_birthday',
    'web_hook_url',
    'cloned_from_library',
    'parent_procedure_id',
    'aasm_state',
    'service_id',
    'duree_conservation_dossiers_dans_ds',
    'cadre_juridique',
    'juridique_required',
    'declarative_with_state',
    'monavis_embed',
    'closed_at',
    'unpublished_at',
    'canonical_procedure_id',
    'api_entreprise_token',
    'draft_revision_id',
    'published_revision_id',
    'allow_expert_review',
    'experts_require_administrateur_invitation',
    'encrypted_api_particulier_token',
    'api_particulier_scopes',
    'api_particulier_sources',
    'routing_enabled',
    'instructeurs_self_management_enabled',
    'procedure_expires_when_termine_enabled',
    'zone_id',
    'lien_dpo',
    'replaced_by_procedure_id',
    'opendata',
    'duree_conservation_etendue_par_ds',
    'max_duree_conservation_dossiers_dans_ds',
    'tags',
    'piece_justificative_multiple',
    'estimated_duration_visible',
    'estimated_dossiers_count',
    'dossiers_count_computed_at',
    'allow_expert_messaging',
    'defaut_groupe_instructeur_id',
    'description_target_audience',
    'description_pj',
    'lien_notice_error',
    'lien_dpo_error',
    'sva_svr',
    'hidden_at_as_template',
    'chorus',
    'template',
    'closing_reason',
    'closing_details',
    'closing_notification_brouillon',
    'closing_notification_en_cours',
    'accuse_lecture',
    'for_tiers_enabled',
    'hide_instructeurs_email',
    'rdv_enabled',
    'routing_alert',
    'api_particulier_token',
    'no_gender',
    'pro_connect_restriction',
    'robots_indexable',
    'admin_default_procedure_presentation_active',
    'admin_default_procedure_presentation_id',
    'api_entreprise_token_expiration_notice_sent_at',
  ]

  NEW_MAX_DUREE_CONSERVATION = Expired::DEFAULT_DOSSIER_RENTENTION_IN_MONTH

  def clone(options: nil, admin:)
    options = default_options if options.nil?

    populate_champ_stable_ids

    procedure = self.deep_clone(include: cloneable_associations(options, admin)) do |original, kopy|
      ClonePiecesJustificativesService.clone_attachments(original, kopy)
      if original.is_a?(TypeDeChamp) && original.type_champ == 'referentiel'
        CloneReferentielService.clone_referentiel(original, kopy, same_admin?(admin))
      end
    end

    procedure = initialize_clone_defaults(procedure, admin)

    procedure = apply_clone_options(procedure, options, admin)

    if !procedure.valid?
      procedure.errors.attribute_names.each do |attribute|
        next if [:notice, :deliberation, :logo].exclude?(attribute)
        procedure.public_send("#{attribute}=", nil)
      end
    end

    transaction do
      procedure.save!
      move_new_children_to_new_parent_coordinate(procedure.draft_revision)
    end

    procedure.draft_revision.revision_types_de_champ.public_only.each(&:destroy) if !options[:clone_champs]
    procedure.draft_revision.revision_types_de_champ.private_only.each(&:destroy) if !options[:clone_annotations]
    procedure.labels = [] if !options[:clone_labels]

    if !same_admin?(admin) || options[:cloned_from_library]
      procedure.draft_revision.types_de_champ_public.each { |tdc| tdc.options&.delete(:old_pj) }
    end

    new_defaut_groupe = procedure.groupe_instructeurs
      .find_by(label: defaut_groupe_instructeur.label) || procedure.groupe_instructeurs.first
    procedure.update!(defaut_groupe_instructeur: new_defaut_groupe)

    procedure.defaut_groupe_instructeur.instructeurs = [admin.instructeur] if !options[:clone_instructeurs] || !same_admin?(admin)

    Flipper.features.each do |feature|
      next if feature.enabled? # don't clone features globally enabled
      next if feature.percentage_of_time_value > 0 || feature.percentage_of_actors_value > 0 # don't clone percentage-based features
      next unless feature_enabled?(feature.key)

      Flipper.enable(feature.key, procedure)
    end

    procedure
  end

  private

  def populate_champ_stable_ids
    TypeDeChamp
      .joins(:revisions)
      .where(procedure_revisions: { procedure_id: id }, stable_id: nil)
      .find_each do |type_de_champ|
        type_de_champ.update_column(:stable_id, type_de_champ.id)
      end
  end

  def same_admin?(admin)
    @same_admin ||= admin.owns?(self)
  end

  def initialize_clone_defaults(procedure, admin)
    procedure.claim_path!(admin, SecureRandom.uuid)
    procedure.aasm_state = :brouillon
    procedure.closed_at = nil
    procedure.unpublished_at = nil
    procedure.published_at = nil
    procedure.auto_archive_on = nil
    procedure.lien_notice = nil
    procedure.duree_conservation_etendue_par_ds = false
    if procedure.duree_conservation_dossiers_dans_ds > NEW_MAX_DUREE_CONSERVATION
      procedure.duree_conservation_dossiers_dans_ds = NEW_MAX_DUREE_CONSERVATION
      procedure.max_duree_conservation_dossiers_dans_ds = NEW_MAX_DUREE_CONSERVATION
    end
    procedure.estimated_dossiers_count = 0
    procedure.published_revision = nil
    procedure.draft_revision.procedure = procedure
    procedure.ask_birthday = false # see issue #4242
    procedure.parent_procedure = self
    procedure.canonical_procedure = nil
    procedure.replaced_by_procedure = nil
    procedure.closing_reason = nil
    procedure.closing_details = nil
    procedure.closing_notification_brouillon = false
    procedure.closing_notification_en_cours = false
    procedure.template = false
    procedure.labels = labels.map(&:dup)
    procedure.routing_alert = false
    procedure.pro_connect_restriction = :none
    procedure.robots_indexable = true
    procedure.admin_default_procedure_presentation_active = false
    procedure.admin_default_procedure_presentation_id = nil
    procedure.api_entreprise_token_expiration_notice_sent_at = nil
    procedure
  end

  def default_options
    {
      clone_administrateurs: true,
      clone_instructeurs: true,
      clone_champs: true,
      clone_annotations: true,
      clone_attestation_acceptation_template: true,
      clone_attestation_refus_template: true,
      clone_zones: true,
      clone_ineligibilite: true,
      clone_monavis_embed: true,
      clone_dossier_submitted_message: true,
      clone_accuse_lecture: true,
      clone_mail_templates: true,
      clone_labels: true,
    }
  end

  def apply_clone_options(procedure, options, admin)
    procedure.cloned_from_library = options[:cloned_from_library]
    procedure.service = nil if !options[:clone_service] || !same_admin?(admin)
    procedure.libelle = options[:clone_libelle] if options[:clone_libelle].present?
    procedure.monavis_embed = nil if !options[:clone_monavis_embed]
    procedure.accuse_lecture = false if !options[:clone_accuse_lecture]
    procedure.experts_require_administrateur_invitation = false if !options[:clone_avis]
    procedure.api_entreprise_token = nil if !options[:clone_api_entreprise_token] || !same_admin?(admin)
    procedure.sva_svr = {} if !options[:clone_sva_svr]

    if !options[:clone_instructeurs] || !same_admin?(admin)
      procedure.routing_enabled = false
      procedure.instructeurs_self_management_enabled = false
    end

    if options[:clone_dossier_submitted_message]
      procedure.draft_revision.dossier_submitted_message = active_revision.dossier_submitted_message.dup
    else
      procedure.draft_revision.dossier_submitted_message = nil
    end

    if !options[:clone_administrateurs] || !same_admin?(admin)
      procedure.administrateurs = [admin]
    else
      procedure.administrateurs = administrateurs
    end

    if !options[:clone_ineligibilite]
      procedure.draft_revision.ineligibilite_rules = nil
      procedure.draft_revision.ineligibilite_enabled = false
      procedure.draft_revision.ineligibilite_message = nil
    end

    if options[:clone_mail_templates]
      procedure.initiated_mail = initiated_mail&.dup
      procedure.received_mail = received_mail&.dup
      procedure.closed_mail = closed_mail&.dup
      procedure.refused_mail = refused_mail&.dup
      procedure.re_instructed_mail = re_instructed_mail&.dup
      procedure.without_continuation_mail = without_continuation_mail&.dup
    end

    if !same_admin?(admin)
      procedure.encrypted_api_particulier_token = nil
      procedure.opendata = true
      procedure.api_particulier_scopes = []
    end

    procedure
  end

  def cloneable_associations(options, admin)
    associations = {
      draft_revision: {
        revision_types_de_champ: :type_de_champ,
        dossier_submitted_message: [],
      },
    }

    if options[:clone_attestation_acceptation_template]
      associations[:attestation_acceptation_template] = []
    end

    if options[:clone_attestation_refus_template]
      associations[:attestation_refus_template] = []
    end

    if options[:clone_zones]
      associations[:zones] = []
    end

    if options[:clone_avis] && same_admin?(admin)
      associations[:experts_procedures] = []
    end

    if options[:clone_instructeurs] && same_admin?(admin)
      associations[:groupe_instructeurs] = [:instructeurs, :contact_information]
    end

    associations
  end
end
