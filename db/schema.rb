# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_12_05_084441) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_buffercache"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"
  disable_extension "postgis_tiger_geocoder"
  enable_extension "sslinfo"
  enable_extension "unaccent"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.jsonb "ocr"
    t.string "service_name", null: false
    t.string "virus_scan_result"
    t.datetime "virus_scanned_at", precision: nil
    t.datetime "watermarked_at", precision: nil
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    t.index ["virus_scan_result"], name: "index_active_storage_blobs_on_virus_scan_result"
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "administrateurs", id: :serial, force: :cascade do |t|
    t.datetime "commentaire_seen_at"
    t.datetime "created_at", precision: nil
    t.bigint "groupe_gestionnaire_id"
    t.datetime "updated_at", precision: nil
    t.bigint "user_id", null: false
    t.index ["groupe_gestionnaire_id"], name: "index_administrateurs_on_groupe_gestionnaire_id"
    t.index ["user_id"], name: "index_administrateurs_on_user_id", unique: true
  end

  create_table "administrateurs_instructeurs", id: false, force: :cascade do |t|
    t.integer "administrateur_id", null: false
    t.datetime "created_at", precision: nil
    t.integer "instructeur_id", null: false
    t.datetime "updated_at", precision: nil
    t.index ["administrateur_id"], name: "index_administrateurs_instructeurs_on_administrateur_id"
    t.index ["instructeur_id", "administrateur_id"], name: "unique_couple_administrateur_instructeur", unique: true
    t.index ["instructeur_id"], name: "index_administrateurs_instructeurs_on_instructeur_id"
  end

  create_table "administrateurs_procedures", id: false, force: :cascade do |t|
    t.bigint "administrateur_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.boolean "manager"
    t.bigint "procedure_id", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["administrateur_id", "procedure_id"], name: "index_unique_admin_proc_couple", unique: true
    t.index ["administrateur_id"], name: "index_administrateurs_procedures_on_administrateur_id"
    t.index ["procedure_id"], name: "index_administrateurs_procedures_on_procedure_id"
  end

  create_table "agent_connect_informations", force: :cascade do |t|
    t.string "amr", default: [], array: true
    t.string "belonging_population"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "given_name"
    t.string "organizational_unit"
    t.string "phone"
    t.string "siret"
    t.string "sub", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "usual_name"
    t.index ["user_id", "sub"], name: "index_agent_connect_informations_on_user_id_and_sub", unique: true
    t.index ["user_id"], name: "index_agent_connect_informations_on_user_id"
  end

  create_table "api_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "administrateur_id", null: false
    t.bigint "allowed_procedure_ids", array: true
    t.inet "authorized_networks", default: [], array: true
    t.datetime "created_at", null: false
    t.string "encrypted_token", null: false
    t.date "expiration_notices_sent_at", default: [], array: true
    t.date "expires_at"
    t.datetime "last_v1_authenticated_at"
    t.datetime "last_v2_authenticated_at"
    t.string "name", null: false
    t.inet "stored_ips", default: [], array: true
    t.datetime "updated_at", null: false
    t.integer "version", default: 3, null: false
    t.boolean "write_access", default: true, null: false
    t.index ["administrateur_id"], name: "index_api_tokens_on_administrateur_id"
  end

  create_table "archives", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "job_status", null: false
    t.text "key", null: false
    t.date "month"
    t.string "time_span_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_profile_id"
    t.string "user_profile_type"
    t.index ["key", "time_span_type", "month"], name: "index_archives_on_key_and_time_span_type_and_month", unique: true
  end

  create_table "archives_groupe_instructeurs", force: :cascade do |t|
    t.bigint "archive_id", null: false
    t.datetime "created_at", null: false
    t.bigint "groupe_instructeur_id", null: false
    t.datetime "updated_at", null: false
    t.index ["archive_id"], name: "index_archives_groupe_instructeurs_on_archive_id"
    t.index ["groupe_instructeur_id"], name: "index_archives_groupe_instructeurs_on_groupe_instructeur_id"
  end

  create_table "assign_tos", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.bigint "groupe_instructeur_id"
    t.integer "instructeur_id"
    t.boolean "manager", default: false
    t.datetime "updated_at", precision: nil
    t.index ["groupe_instructeur_id", "instructeur_id"], name: "unique_couple_groupe_instructeur_instructeur", unique: true
    t.index ["groupe_instructeur_id"], name: "index_assign_tos_on_groupe_instructeur_id"
    t.index ["instructeur_id"], name: "index_assign_tos_on_instructeur_id"
  end

  create_table "attestation_templates", id: :serial, force: :cascade do |t|
    t.boolean "activated"
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.text "footer"
    t.jsonb "json_body"
    t.string "kind", null: false
    t.string "label_direction"
    t.string "label_logo"
    t.boolean "official_layout", default: true, null: false
    t.integer "procedure_id"
    t.string "state", default: "published"
    t.text "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version", default: 1, null: false
    t.index ["procedure_id", "version", "state", "kind"], name: "index_attestation_templates_on_procedure_version_state_kind", unique: true
  end

  create_table "attestations", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "dossier_id", null: false
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["dossier_id"], name: "index_attestations_on_dossier_id", unique: true
  end

  create_table "avis", id: :serial, force: :cascade do |t|
    t.text "answer"
    t.integer "claimant_id", null: false
    t.string "claimant_type"
    t.boolean "confidentiel", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "dossier_id"
    t.string "email"
    t.bigint "experts_procedure_id"
    t.text "introduction"
    t.boolean "question_answer"
    t.string "question_label"
    t.datetime "reminded_at", precision: nil
    t.datetime "revoked_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["claimant_id"], name: "index_avis_on_claimant_id"
    t.index ["dossier_id"], name: "index_avis_on_dossier_id"
    t.index ["experts_procedure_id"], name: "index_avis_on_experts_procedure_id"
  end

  create_table "batch_operations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "failed_dossier_ids", default: [], null: false, array: true
    t.datetime "finished_at", precision: nil
    t.bigint "instructeur_id", null: false
    t.string "operation", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "run_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.bigint "success_dossier_ids", default: [], null: false, array: true
    t.datetime "updated_at", null: false
  end

  create_table "batch_operations_groupe_instructeurs", force: :cascade do |t|
    t.bigint "batch_operation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "groupe_instructeur_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bill_signatures", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "digest"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "bulk_messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "dossier_count"
    t.string "dossier_state"
    t.bigint "instructeur_id", null: false
    t.bigint "procedure_id"
    t.datetime "sent_at", precision: nil, null: false
    t.datetime "updated_at", null: false
  end

  create_table "champs", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.jsonb "data"
    t.datetime "discarded_at"
    t.integer "dossier_id"
    t.integer "etablissement_id"
    t.string "external_id"
    t.string "external_state"
    t.string "fetch_external_data_exceptions", array: true
    t.bigint "parent_id"
    t.boolean "prefilled"
    t.boolean "private", default: false, null: false
    t.datetime "rebased_at", precision: nil
    t.string "row_id"
    t.bigint "stable_id"
    t.string "stream"
    t.string "type"
    t.integer "type_de_champ_id"
    t.datetime "updated_at", precision: nil
    t.text "updated_by"
    t.string "value"
    t.jsonb "value_json"
    t.index ["dossier_id", "stream", "stable_id", "row_id"], name: "index_champs_on_stream_and_public_id", unique: true, nulls_not_distinct: true
    t.index ["dossier_id"], name: "index_champs_on_dossier_id"
    t.index ["etablissement_id"], name: "index_champs_on_etablissement_id"
    t.index ["row_id"], name: "index_champs_on_row_id"
    t.index ["stable_id"], name: "index_champs_on_stable_id"
    t.index ["type"], name: "index_champs_on_type"
  end

  create_table "closed_mails", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.integer "procedure_id"
    t.string "subject"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["procedure_id"], name: "index_closed_mails_on_procedure_id"
  end

  create_table "commentaire_groupe_gestionnaires", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "discarded_at", precision: nil
    t.string "gestionnaire_email"
    t.bigint "gestionnaire_id"
    t.bigint "groupe_gestionnaire_id"
    t.string "sender_email"
    t.bigint "sender_id", null: false
    t.string "sender_type", null: false
    t.datetime "updated_at", null: false
    t.index ["gestionnaire_id"], name: "index_commentaire_groupe_gestionnaires_on_gestionnaire_id"
    t.index ["groupe_gestionnaire_id"], name: "index_commentaire_groupe_gestionnaires_on_groupe_gestionnaire"
  end

  create_table "commentaires", id: :serial, force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "discarded_at", precision: nil
    t.integer "dossier_id"
    t.string "email"
    t.bigint "expert_id"
    t.bigint "instructeur_id"
    t.datetime "seen_by_recipient_at"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["dossier_id"], name: "index_commentaires_on_dossier_id"
    t.index ["expert_id"], name: "index_commentaires_on_expert_id"
    t.index ["instructeur_id"], name: "index_commentaires_on_instructeur_id"
    t.index ["seen_by_recipient_at"], name: "index_commentaires_on_seen_by_recipient_at"
  end

  create_table "contact_forms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dossier_id"
    t.string "email"
    t.boolean "for_admin", default: false, null: false
    t.string "phone"
    t.string "question_type", null: false
    t.string "subject", null: false
    t.string "tags", default: [], array: true
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_contact_forms_on_user_id"
  end

  create_table "contact_informations", force: :cascade do |t|
    t.text "adresse", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "groupe_instructeur_id", null: false
    t.text "horaires", null: false
    t.string "nom", null: false
    t.string "telephone", null: false
    t.datetime "updated_at", null: false
    t.index ["groupe_instructeur_id", "nom"], name: "index_contact_informations_on_gi_and_nom", unique: true
    t.index ["groupe_instructeur_id"], name: "index_contact_informations_on_groupe_instructeur_id"
  end

  create_table "default_zones_administrateurs", id: false, force: :cascade do |t|
    t.bigint "administrateur_id"
    t.bigint "zone_id"
    t.index ["administrateur_id"], name: "index_default_zones_administrateurs_on_administrateur_id"
    t.index ["zone_id"], name: "index_default_zones_administrateurs_on_zone_id"
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", precision: nil
    t.string "cron"
    t.datetime "failed_at", precision: nil
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "locked_at", precision: nil
    t.string "locked_by"
    t.integer "priority", default: 0, null: false
    t.string "queue"
    t.datetime "run_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "deleted_dossiers", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil
    t.date "depose_at"
    t.bigint "dossier_id"
    t.bigint "groupe_instructeur_id"
    t.bigint "procedure_id"
    t.string "reason"
    t.bigint "revision_id"
    t.string "state"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["deleted_at"], name: "index_deleted_dossiers_on_deleted_at"
    t.index ["dossier_id"], name: "index_deleted_dossiers_on_dossier_id", unique: true
    t.index ["procedure_id"], name: "index_deleted_dossiers_on_procedure_id"
    t.index ["user_id"], name: "index_deleted_dossiers_on_user_id"
  end

  create_table "dossier_assignments", force: :cascade do |t|
    t.datetime "assigned_at", precision: nil, null: false
    t.string "assigned_by"
    t.bigint "dossier_id", null: false
    t.bigint "groupe_instructeur_id"
    t.string "groupe_instructeur_label"
    t.string "mode", null: false
    t.bigint "previous_groupe_instructeur_id"
    t.string "previous_groupe_instructeur_label"
    t.index ["dossier_id"], name: "index_dossier_assignments_on_dossier_id"
  end

  create_table "dossier_batch_operations", force: :cascade do |t|
    t.bigint "batch_operation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_operation_id"], name: "index_dossier_batch_operations_on_batch_operation_id"
    t.index ["dossier_id"], name: "index_dossier_batch_operations_on_dossier_id"
  end

  create_table "dossier_corrections", force: :cascade do |t|
    t.bigint "commentaire_id"
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.string "reason", default: "incorrect", null: false
    t.datetime "resolved_at"
    t.datetime "updated_at", null: false
    t.index ["commentaire_id"], name: "index_dossier_corrections_on_commentaire_id"
    t.index ["dossier_id"], name: "index_dossier_corrections_on_dossier_id"
    t.index ["resolved_at"], name: "index_dossier_corrections_on_resolved_at", where: "((resolved_at IS NULL) OR (resolved_at IS NOT NULL))"
  end

  create_table "dossier_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.bigint "label_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dossier_id"], name: "index_dossier_labels_on_dossier_id"
    t.index ["label_id"], name: "index_dossier_labels_on_label_id"
  end

  create_table "dossier_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "display_at"
    t.bigint "dossier_id", null: false
    t.bigint "instructeur_id", null: false
    t.string "notification_type", null: false
    t.datetime "updated_at", null: false
    t.index ["dossier_id", "notification_type", "instructeur_id"], name: "unique_dossier_instructeur_notification", unique: true
    t.index ["dossier_id"], name: "index_dossier_notifications_on_dossier_id"
    t.index ["instructeur_id"], name: "index_dossier_notifications_on_instructeur_id"
  end

  create_table "dossier_operation_logs", force: :cascade do |t|
    t.boolean "automatic_operation", default: false, null: false
    t.bigint "bill_signature_id"
    t.datetime "created_at", precision: nil, null: false
    t.jsonb "data"
    t.text "digest"
    t.bigint "dossier_id"
    t.datetime "executed_at", precision: nil
    t.datetime "keep_until", precision: nil
    t.string "operation", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["bill_signature_id"], name: "index_dossier_operation_logs_on_bill_signature_id"
    t.index ["dossier_id"], name: "index_dossier_operation_logs_on_dossier_id"
    t.index ["id"], name: "index_dossier_operation_logs_on_id", where: "(data IS NOT NULL)"
    t.index ["keep_until"], name: "index_dossier_operation_logs_on_keep_until"
  end

  create_table "dossier_pending_responses", force: :cascade do |t|
    t.bigint "commentaire_id"
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.datetime "responded_at"
    t.datetime "updated_at", null: false
    t.index ["commentaire_id"], name: "index_dossier_pending_responses_on_commentaire_id"
    t.index ["dossier_id"], name: "index_dossier_pending_responses_on_dossier_id"
    t.index ["responded_at"], name: "index_dossier_pending_responses_on_responded_at", where: "(responded_at IS NULL)"
  end

  create_table "dossier_submitted_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_on_submit_by_usager"
    t.datetime "updated_at", null: false
  end

  create_table "dossier_transfer_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.string "from", null: false
    t.boolean "from_support", default: false, null: false
    t.string "to", null: false
    t.datetime "updated_at", null: false
    t.index ["dossier_id"], name: "index_dossier_transfer_logs_on_dossier_id"
  end

  create_table "dossier_transfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "from_support", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_dossier_transfers_on_email"
  end

  create_table "dossiers", id: :serial, force: :cascade do |t|
    t.date "accuse_lecture_agreement_at"
    t.string "api_entreprise_job_exceptions", array: true
    t.boolean "archived", default: false
    t.datetime "archived_at", precision: nil
    t.string "archived_by"
    t.boolean "autorisation_donnees"
    t.bigint "batch_operation_id"
    t.datetime "brouillon_close_to_expiration_notice_sent_at", precision: nil
    t.interval "conservation_extension", default: "PT0S"
    t.datetime "created_at", precision: nil
    t.datetime "declarative_triggered_at", precision: nil
    t.string "deleted_user_email_never_send"
    t.datetime "depose_at", precision: nil
    t.bigint "dossier_transfer_id"
    t.bigint "editing_fork_origin_id"
    t.datetime "en_construction_at", precision: nil
    t.datetime "en_construction_close_to_expiration_notice_sent_at", precision: nil
    t.datetime "en_instruction_at", precision: nil
    t.datetime "expired_at"
    t.boolean "for_procedure_preview", default: false, null: false
    t.boolean "for_tiers", default: false, null: false
    t.boolean "forced_groupe_instructeur", default: false, null: false
    t.bigint "groupe_instructeur_id"
    t.datetime "groupe_instructeur_updated_at", precision: nil
    t.datetime "hidden_by_administration_at", precision: nil
    t.datetime "hidden_by_expired_at"
    t.string "hidden_by_reason"
    t.datetime "hidden_by_user_at", precision: nil
    t.datetime "identity_updated_at", precision: nil
    t.datetime "last_avis_piece_jointe_updated_at"
    t.datetime "last_avis_updated_at", precision: nil
    t.datetime "last_champ_instructeur_updated_at"
    t.datetime "last_champ_piece_jointe_updated_at"
    t.datetime "last_champ_private_updated_at", precision: nil
    t.datetime "last_champ_updated_at", precision: nil
    t.datetime "last_commentaire_piece_jointe_updated_at"
    t.datetime "last_commentaire_updated_at", precision: nil
    t.string "mandataire_first_name"
    t.string "mandataire_last_name"
    t.text "motivation"
    t.bigint "parent_dossier_id"
    t.string "prefill_token"
    t.boolean "prefilled"
    t.string "private_search_terms"
    t.datetime "processed_at", precision: nil
    t.bigint "revision_id"
    t.string "search_terms"
    t.string "state"
    t.bigint "submitted_revision_id"
    t.date "sva_svr_decision_on"
    t.datetime "sva_svr_decision_triggered_at"
    t.datetime "termine_close_to_expiration_notice_sent_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["archived"], name: "index_dossiers_on_archived"
    t.index ["batch_operation_id"], name: "index_dossiers_on_batch_operation_id"
    t.index ["dossier_transfer_id"], name: "index_dossiers_on_dossier_transfer_id"
    t.index ["editing_fork_origin_id"], name: "index_dossiers_on_editing_fork_origin_id"
    t.index ["groupe_instructeur_id", "state", "archived"], name: "index_dossiers_on_groupe_instructeur_id_and_state_and_archived", where: "((hidden_by_administration_at IS NULL) AND (hidden_by_expired_at IS NULL))"
    t.index ["groupe_instructeur_id"], name: "index_dossiers_on_groupe_instructeur_id"
    t.index ["parent_dossier_id"], name: "index_dossiers_on_parent_dossier_id"
    t.index ["prefill_token"], name: "index_dossiers_on_prefill_token", unique: true
    t.index ["revision_id"], name: "index_dossiers_on_revision_id"
    t.index ["state"], name: "index_dossiers_on_state"
    t.index ["user_id"], name: "index_dossiers_on_user_id"
  end

  create_table "email_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_id"
    t.string "method", null: false
    t.datetime "processed_at", precision: nil
    t.string "status", null: false
    t.string "subject", null: false
    t.string "to", null: false
    t.datetime "updated_at", null: false
  end

  create_table "etablissements", id: :serial, force: :cascade do |t|
    t.string "adresse"
    t.date "association_date_creation"
    t.date "association_date_declaration"
    t.date "association_date_publication"
    t.text "association_objet"
    t.string "association_rna"
    t.string "association_titre"
    t.string "code_insee_localite"
    t.string "code_postal"
    t.string "complement_adresse"
    t.datetime "created_at", precision: nil
    t.boolean "diffusable_commercialement"
    t.integer "dossier_id"
    t.string "enseigne"
    t.jsonb "entreprise_bilans_bdf"
    t.string "entreprise_bilans_bdf_monnaie"
    t.bigint "entreprise_capital_social"
    t.string "entreprise_code_effectif_entreprise"
    t.date "entreprise_date_creation"
    t.string "entreprise_effectif_annee"
    t.decimal "entreprise_effectif_annuel"
    t.string "entreprise_effectif_annuel_annee"
    t.decimal "entreprise_effectif_mensuel"
    t.string "entreprise_effectif_mois"
    t.string "entreprise_etat_administratif"
    t.string "entreprise_forme_juridique"
    t.string "entreprise_forme_juridique_code"
    t.string "entreprise_nom"
    t.string "entreprise_nom_commercial"
    t.string "entreprise_numero_tva_intracommunautaire"
    t.string "entreprise_prenom"
    t.string "entreprise_raison_sociale"
    t.string "entreprise_siren"
    t.string "entreprise_siret_siege_social"
    t.string "libelle_naf"
    t.string "localite"
    t.string "naf"
    t.string "nom_pays"
    t.string "nom_voie"
    t.string "numero_voie"
    t.boolean "siege_social"
    t.string "siret"
    t.string "type_voie"
    t.datetime "updated_at", precision: nil
    t.index ["dossier_id"], name: "index_etablissements_on_dossier_id", unique: true
  end

  create_table "exercices", id: :serial, force: :cascade do |t|
    t.string "ca"
    t.datetime "created_at", precision: nil
    t.datetime "dateFinExercice", precision: nil
    t.datetime "date_fin_exercice", precision: nil
    t.integer "date_fin_exercice_timestamp"
    t.integer "etablissement_id"
    t.datetime "updated_at", precision: nil
    t.index ["etablissement_id"], name: "index_exercices_on_etablissement_id"
  end

  create_table "experts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_experts_on_user_id", unique: true
  end

  create_table "experts_procedures", force: :cascade do |t|
    t.boolean "allow_decision_access", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "expert_id", null: false
    t.boolean "notify_on_new_avis", default: true, null: false
    t.boolean "notify_on_new_message", default: false, null: false
    t.bigint "procedure_id", null: false
    t.datetime "revoked_at", precision: nil
    t.datetime "updated_at", null: false
    t.index ["expert_id", "procedure_id"], name: "index_experts_procedures_on_expert_id_and_procedure_id", unique: true
    t.index ["expert_id"], name: "index_experts_procedures_on_expert_id"
    t.index ["procedure_id"], name: "index_experts_procedures_on_procedure_id"
  end

  create_table "export_templates", force: :cascade do |t|
    t.jsonb "attestation"
    t.boolean "avis_attachments", default: false, null: false
    t.boolean "commentaires_attachments", default: false, null: false
    t.jsonb "content", default: {}
    t.datetime "created_at", null: false
    t.jsonb "dossier_folder", null: false
    t.jsonb "export_pdf", null: false
    t.jsonb "exported_columns", default: [], null: false, array: true
    t.bigint "groupe_instructeur_id", null: false
    t.boolean "justificatif_motivation", default: false, null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.jsonb "pjs", default: [], null: false, array: true
    t.boolean "shared", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["groupe_instructeur_id"], name: "index_export_templates_on_groupe_instructeur_id"
  end

  create_table "exports", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "dossiers_count"
    t.bigint "export_template_id"
    t.jsonb "filtered_columns", default: [], null: false, array: true
    t.string "format", null: false
    t.boolean "include_archived", default: false, null: false
    t.bigint "instructeur_id"
    t.string "job_status", default: "pending", null: false
    t.text "key", null: false
    t.bigint "procedure_presentation_id"
    t.jsonb "procedure_presentation_snapshot"
    t.jsonb "sorted_column"
    t.string "statut", default: "tous"
    t.string "time_span_type", default: "everything", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_profile_id"
    t.string "user_profile_type"
    t.index ["export_template_id"], name: "index_exports_on_export_template_id"
    t.index ["instructeur_id"], name: "index_exports_on_instructeur_id"
    t.index ["key"], name: "index_exports_on_key"
    t.index ["procedure_presentation_id"], name: "index_exports_on_procedure_presentation_id"
  end

  create_table "exports_groupe_instructeurs", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "export_id", null: false
    t.bigint "groupe_instructeur_id", null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "key", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "follow_commentaire_groupe_gestionnaires", force: :cascade do |t|
    t.datetime "commentaire_seen_at", precision: nil
    t.datetime "created_at", null: false
    t.bigint "gestionnaire_id", null: false
    t.bigint "groupe_gestionnaire_id"
    t.bigint "sender_id"
    t.string "sender_type"
    t.datetime "unfollowed_at", precision: nil
    t.datetime "updated_at", null: false
    t.index ["gestionnaire_id", "groupe_gestionnaire_id", "sender_id", "sender_type", "unfollowed_at"], name: "index_follow_commentaire_on_groupe_gestionnaire_unfollow", unique: true
    t.index ["gestionnaire_id"], name: "index_follow_commentaire_on_gestionnaire"
    t.index ["groupe_gestionnaire_id"], name: "index_follow_commentaire_on_groupe_gestionnaire"
  end

  create_table "follows", id: :serial, force: :cascade do |t|
    t.datetime "annotations_privees_seen_at", precision: nil, null: false
    t.datetime "avis_seen_at", precision: nil, null: false
    t.datetime "created_at", precision: nil
    t.datetime "demande_seen_at", precision: nil, null: false
    t.integer "dossier_id", null: false
    t.integer "instructeur_id", null: false
    t.datetime "messagerie_seen_at", precision: nil, null: false
    t.datetime "unfollowed_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["dossier_id"], name: "index_follows_on_dossier_id"
    t.index ["instructeur_id", "dossier_id", "unfollowed_at"], name: "uniqueness_index", unique: true
    t.index ["instructeur_id"], name: "index_follows_on_instructeur_id"
    t.index ["unfollowed_at"], name: "index_follows_on_unfollowed_at"
  end

  create_table "france_connect_informations", id: :serial, force: :cascade do |t|
    t.date "birthdate"
    t.string "birthplace"
    t.datetime "created_at", precision: nil, null: false
    t.jsonb "data"
    t.string "email_france_connect"
    t.string "email_merge_token"
    t.datetime "email_merge_token_created_at"
    t.string "family_name"
    t.string "france_connect_particulier_id"
    t.string "gender"
    t.string "given_name"
    t.string "merge_token"
    t.datetime "merge_token_created_at", precision: nil
    t.string "requested_email"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["email_merge_token"], name: "index_france_connect_informations_on_email_merge_token"
    t.index ["france_connect_particulier_id"], name: "idx_france_connect_particulier_id"
    t.index ["merge_token"], name: "index_france_connect_informations_on_merge_token"
    t.index ["user_id"], name: "index_france_connect_informations_on_user_id"
  end

  create_table "geo_areas", force: :cascade do |t|
    t.string "cadastre_error"
    t.string "cadastre_state"
    t.bigint "champ_id"
    t.datetime "created_at", precision: nil
    t.string "geo_reference_id"
    t.jsonb "geometry"
    t.jsonb "properties"
    t.string "source"
    t.datetime "updated_at", precision: nil
    t.index ["cadastre_state"], name: "index_geo_areas_on_cadastre_state"
    t.index ["champ_id"], name: "index_geo_areas_on_champ_id"
    t.index ["source"], name: "index_geo_areas_on_source"
  end

  create_table "gestionnaires", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_gestionnaires_on_user_id", unique: true
  end

  create_table "gestionnaires_groupe_gestionnaires", id: false, force: :cascade do |t|
    t.bigint "gestionnaire_id", null: false
    t.bigint "groupe_gestionnaire_id", null: false
    t.index ["gestionnaire_id", "groupe_gestionnaire_id"], name: "index_on_gestionnaire_and_groupe_gestionnaire"
    t.index ["groupe_gestionnaire_id", "gestionnaire_id"], name: "index_on_groupe_gestionnaire_and_gestionnaire"
  end

  create_table "groupe_gestionnaires", force: :cascade do |t|
    t.string "ancestry", default: "/", null: false, collation: "C"
    t.datetime "created_at", null: false
    t.bigint "groupe_gestionnaire_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_groupe_gestionnaires_on_ancestry"
    t.index ["groupe_gestionnaire_id"], name: "index_groupe_gestionnaires_on_groupe_gestionnaire_id"
    t.index ["name"], name: "index_groupe_gestionnaires_on_name"
  end

  create_table "groupe_instructeurs", force: :cascade do |t|
    t.boolean "closed", default: false
    t.datetime "created_at", precision: nil, null: false
    t.text "label", null: false
    t.bigint "procedure_id", null: false
    t.jsonb "routing_rule"
    t.boolean "unique_routing_rule", default: false, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "valid_routing_rule", default: false, null: false
    t.index ["closed", "procedure_id"], name: "index_groupe_instructeurs_on_closed_and_procedure_id"
    t.index ["procedure_id", "label"], name: "index_groupe_instructeurs_on_procedure_id_and_label", unique: true
    t.index ["procedure_id"], name: "index_groupe_instructeurs_on_procedure_id"
  end

  create_table "individuals", id: :serial, force: :cascade do |t|
    t.date "birthdate"
    t.datetime "created_at", precision: nil
    t.integer "dossier_id"
    t.string "email"
    t.datetime "email_verified_at"
    t.string "gender"
    t.string "nom"
    t.string "notification_method"
    t.string "prenom"
    t.datetime "updated_at", precision: nil
    t.index ["dossier_id"], name: "index_individuals_on_dossier_id", unique: true
    t.index ["email"], name: "index_individuals_on_email"
  end

  create_table "initiated_mails", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.integer "procedure_id"
    t.string "subject"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["procedure_id"], name: "index_initiated_mails_on_procedure_id"
  end

  create_table "instructeurs", id: :serial, force: :cascade do |t|
    t.string "agent_connect_id_token"
    t.boolean "bypass_email_login_token", default: false, null: false
    t.datetime "created_at", precision: nil
    t.text "encrypted_login_token"
    t.datetime "login_token_created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_instructeurs_on_user_id", unique: true
  end

  create_table "instructeurs_procedures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "daily_email_summary", default: false, null: false
    t.string "display_annotation_instructeur_notifications", default: "followed", null: false
    t.string "display_attente_avis_notifications", default: "followed", null: false
    t.string "display_attente_correction_notifications", default: "followed", null: false
    t.string "display_attente_reponse_notifications", default: "followed", null: false
    t.string "display_avis_externe_notifications", default: "followed", null: false
    t.string "display_dossier_depose_notifications", default: "all", null: false
    t.string "display_dossier_modifie_notifications", default: "followed", null: false
    t.string "display_message_notifications", default: "followed", null: false
    t.boolean "instant_email_dossier_deletion", default: true, null: false
    t.boolean "instant_email_dossier_expiration", default: true, null: false
    t.boolean "instant_email_dossier_expired", default: true, null: false
    t.boolean "instant_email_new_dossier", default: false, null: false
    t.boolean "instant_email_new_expert_avis", default: false, null: false
    t.boolean "instant_email_new_message", default: false, null: false
    t.bigint "instructeur_id", null: false
    t.bigint "last_revision_seen_id"
    t.integer "position", null: false
    t.bigint "procedure_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "weekly_email_summary", default: false, null: false
    t.index ["instructeur_id", "procedure_id"], name: "index_instructeurs_procedures_on_instructeur_and_procedure", unique: true
    t.index ["instructeur_id"], name: "index_instructeurs_procedures_on_instructeur_id"
    t.index ["procedure_id"], name: "index_instructeurs_procedures_on_procedure_id"
  end

  create_table "invites", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "dossier_id"
    t.string "email"
    t.string "email_sender"
    t.text "message"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["dossier_id"], name: "index_invites_on_dossier_id"
    t.index ["email", "dossier_id"], name: "index_invites_on_email_and_dossier_id", unique: true
    t.index ["user_id"], name: "index_invites_on_user_id"
  end

  create_table "labels", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "position"
    t.bigint "procedure_id", null: false
    t.datetime "updated_at", null: false
    t.index ["procedure_id"], name: "index_labels_on_procedure_id"
  end

  create_table "llm_rule_suggestion_items", force: :cascade do |t|
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.text "justification"
    t.bigint "llm_rule_suggestion_id", null: false
    t.string "model"
    t.string "op_kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "stable_id"
    t.datetime "updated_at", null: false
    t.string "verify_status", default: "pending", null: false
    t.index ["llm_rule_suggestion_id"], name: "index_items_on_llm_rule_suggestion_id"
  end

  create_table "llm_rule_suggestions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "procedure_revision_id", null: false
    t.string "rule", null: false
    t.string "schema_hash", null: false
    t.string "state", default: "pending", null: false
    t.jsonb "token_usage"
    t.datetime "updated_at", null: false
    t.index ["procedure_revision_id", "schema_hash", "rule"], name: "index_llm_rule_suggestions_on_revision_schema_rule"
    t.index ["procedure_revision_id"], name: "index_llm_rule_suggestions_on_procedure_revision_id"
  end

  create_table "maintenance_tasks_runs", force: :cascade do |t|
    t.text "arguments"
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.string "cursor"
    t.datetime "ended_at", precision: nil
    t.string "error_class"
    t.string "error_message"
    t.string "job_id"
    t.integer "lock_version", default: 0, null: false
    t.text "metadata"
    t.datetime "started_at", precision: nil
    t.string "status", default: "enqueued", null: false
    t.string "task_name", null: false
    t.bigint "tick_count", default: 0, null: false
    t.bigint "tick_total"
    t.float "time_running", default: 0.0, null: false
    t.datetime "updated_at", null: false
    t.index ["task_name", "status", "created_at"], name: "index_maintenance_tasks_runs", order: { created_at: :desc }
  end

  create_table "merge_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_user_email", null: false
    t.bigint "from_user_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_merge_logs_on_user_id"
  end

  create_table "module_api_cartos", id: :serial, force: :cascade do |t|
    t.boolean "cadastre", default: false
    t.datetime "created_at", precision: nil
    t.boolean "migrated"
    t.integer "procedure_id"
    t.boolean "quartiers_prioritaires", default: false
    t.datetime "updated_at", precision: nil
    t.boolean "use_api_carto", default: false
    t.index ["procedure_id"], name: "index_module_api_cartos_on_procedure_id", unique: true
  end

  create_table "procedure_paths", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "path"
    t.bigint "procedure_id", null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_procedure_paths_on_path", unique: true
    t.index ["procedure_id"], name: "index_procedure_paths_on_procedure_id"
  end

  create_table "procedure_presentations", id: :serial, force: :cascade do |t|
    t.jsonb "a_suivre_filters", default: [], null: false, array: true
    t.jsonb "archives_filters", default: [], null: false, array: true
    t.integer "assign_to_id"
    t.datetime "created_at", precision: nil
    t.jsonb "displayed_columns", default: [], null: false, array: true
    t.jsonb "displayed_fields", default: [{"label"=>"Demandeur", "table"=>"user", "column"=>"email"}], null: false
    t.jsonb "expirant_filters", default: [], null: false, array: true
    t.jsonb "filters", default: {"tous"=>[], "suivis"=>[], "traites"=>[], "a-suivre"=>[], "archives"=>[], "expirant"=>[], "supprimes"=>[]}, null: false
    t.boolean "filters_expanded", default: true, null: false
    t.jsonb "sort", default: {"order"=>"desc", "table"=>"notifications", "column"=>"notifications"}, null: false
    t.jsonb "sorted_column"
    t.jsonb "suivis_filters", default: [], null: false, array: true
    t.jsonb "supprimes_filters", default: [], null: false, array: true
    t.jsonb "supprimes_recemment_filters", default: [], null: false, array: true
    t.jsonb "tous_filters", default: [], null: false, array: true
    t.jsonb "traites_filters", default: [], null: false, array: true
    t.datetime "updated_at", precision: nil
    t.index ["assign_to_id"], name: "index_procedure_presentations_on_assign_to_id", unique: true
  end

  create_table "procedure_revision_types_de_champ", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "parent_id"
    t.integer "position", null: false
    t.bigint "revision_id", null: false
    t.bigint "type_de_champ_id", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["parent_id"], name: "index_procedure_revision_types_de_champ_on_parent_id"
    t.index ["revision_id"], name: "index_procedure_revision_types_de_champ_on_revision_id"
    t.index ["type_de_champ_id"], name: "index_procedure_revision_types_de_champ_on_type_de_champ_id"
  end

  create_table "procedure_revisions", force: :cascade do |t|
    t.bigint "administrateur_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "dossier_submitted_message_id"
    t.boolean "ineligibilite_enabled", default: false, null: false
    t.text "ineligibilite_message"
    t.jsonb "ineligibilite_rules"
    t.bigint "procedure_id", null: false
    t.datetime "published_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["administrateur_id"], name: "index_procedure_revisions_on_administrateur_id"
    t.index ["dossier_submitted_message_id"], name: "index_procedure_revisions_on_dossier_submitted_message_id"
    t.index ["procedure_id"], name: "index_procedure_revisions_on_procedure_id"
  end

  create_table "procedure_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_procedure_tags_on_name", unique: true
  end

  create_table "procedure_tags_procedures", id: false, force: :cascade do |t|
    t.bigint "procedure_id", null: false
    t.bigint "procedure_tag_id", null: false
    t.index ["procedure_id", "procedure_tag_id"], name: "index_procedures_tags_on_procedure_id_and_tag_id"
    t.index ["procedure_tag_id", "procedure_id"], name: "index_procedures_tags_on_tag_id_and_procedure_id"
  end

  create_table "procedures", id: :serial, force: :cascade do |t|
    t.string "aasm_state", default: "brouillon"
    t.boolean "accuse_lecture", default: false, null: false
    t.boolean "allow_expert_messaging", default: true, null: false
    t.boolean "allow_expert_review", default: true, null: false
    t.string "api_entreprise_token"
    t.datetime "api_entreprise_token_expires_at", precision: nil
    t.text "api_particulier_scopes", default: [], array: true
    t.jsonb "api_particulier_sources", default: {}
    t.string "api_particulier_token"
    t.boolean "ask_birthday", default: false, null: false
    t.date "auto_archive_on"
    t.string "cadre_juridique"
    t.bigint "canonical_procedure_id"
    t.jsonb "chorus", default: {}, null: false
    t.boolean "cloned_from_library", default: false
    t.datetime "closed_at", precision: nil
    t.string "closing_details"
    t.boolean "closing_notification_brouillon", default: false, null: false
    t.boolean "closing_notification_en_cours", default: false, null: false
    t.string "closing_reason"
    t.datetime "created_at", precision: nil, null: false
    t.string "declarative_with_state"
    t.bigint "defaut_groupe_instructeur_id"
    t.string "description"
    t.string "description_pj"
    t.string "description_target_audience"
    t.datetime "dossiers_count_computed_at", precision: nil
    t.bigint "draft_revision_id"
    t.integer "duree_conservation_dossiers_dans_ds"
    t.boolean "duree_conservation_etendue_par_ds", default: false, null: false
    t.string "encrypted_api_particulier_token"
    t.integer "estimated_dossiers_count"
    t.boolean "estimated_duration_visible", default: true, null: false
    t.boolean "euro_flag", default: false
    t.boolean "experts_require_administrateur_invitation", default: false
    t.boolean "for_individual", default: false
    t.boolean "for_tiers_enabled", default: true, null: false
    t.datetime "hidden_at", precision: nil
    t.datetime "hidden_at_as_template", precision: nil
    t.boolean "hide_instructeurs_email", default: false, null: false
    t.boolean "instructeurs_self_management_enabled", default: false
    t.boolean "juridique_required", default: true
    t.string "libelle"
    t.string "lien_dpo"
    t.text "lien_dpo_error"
    t.string "lien_notice"
    t.text "lien_notice_error"
    t.string "lien_site_web"
    t.integer "max_duree_conservation_dossiers_dans_ds", default: 12, null: false
    t.text "monavis_embed"
    t.boolean "no_gender", default: false, null: false
    t.boolean "opendata", default: true
    t.string "organisation"
    t.bigint "parent_procedure_id"
    t.string "path"
    t.boolean "piece_justificative_multiple", default: true, null: false
    t.boolean "pro_connect_restricted", default: false, null: false
    t.string "pro_connect_restriction", default: "none", null: false
    t.boolean "procedure_expires_when_termine_enabled", default: true
    t.datetime "published_at", precision: nil
    t.bigint "published_revision_id"
    t.boolean "rdv_enabled", default: false, null: false
    t.bigint "replaced_by_procedure_id"
    t.boolean "robots_indexable", default: true, null: false
    t.boolean "routing_alert", default: false, null: false
    t.boolean "routing_enabled"
    t.bigint "service_id"
    t.jsonb "sva_svr", default: {}, null: false
    t.text "tags", default: [], array: true
    t.boolean "template", default: false, null: false
    t.datetime "unpublished_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.string "web_hook_url"
    t.datetime "whitelisted_at", precision: nil
    t.bigint "zone_id"
    t.index ["api_particulier_sources"], name: "index_procedures_on_api_particulier_sources", using: :gin
    t.index ["declarative_with_state"], name: "index_procedures_on_declarative_with_state"
    t.index ["defaut_groupe_instructeur_id"], name: "index_procedures_on_defaut_groupe_instructeur_id"
    t.index ["draft_revision_id"], name: "index_procedures_on_draft_revision_id"
    t.index ["hidden_at"], name: "index_procedures_on_hidden_at"
    t.index ["libelle"], name: "index_procedures_on_libelle"
    t.index ["parent_procedure_id"], name: "index_procedures_on_parent_procedure_id"
    t.index ["path", "closed_at", "hidden_at", "unpublished_at"], name: "procedure_path_uniqueness", unique: true
    t.index ["path", "closed_at", "hidden_at"], name: "index_procedures_on_path_and_closed_at_and_hidden_at", unique: true
    t.index ["procedure_expires_when_termine_enabled"], name: "index_procedures_on_procedure_expires_when_termine_enabled"
    t.index ["published_revision_id"], name: "index_procedures_on_published_revision_id"
    t.index ["service_id"], name: "index_procedures_on_service_id"
    t.index ["tags"], name: "index_procedures_on_tags", using: :gin
    t.index ["zone_id"], name: "index_procedures_on_zone_id"
  end

  create_table "procedures_zones", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "procedure_id"
    t.datetime "updated_at", null: false
    t.bigint "zone_id"
    t.index ["procedure_id"], name: "index_procedures_zones_on_procedure_id"
    t.index ["zone_id"], name: "index_procedures_zones_on_zone_id"
  end

  create_table "rdv_connections", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "instructeur_id", null: false
    t.string "refresh_token"
    t.datetime "updated_at", null: false
    t.index ["instructeur_id"], name: "index_rdv_connections_on_instructeur_id", unique: true
  end

  create_table "rdvs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dossier_id", null: false
    t.bigint "instructeur_id", null: false
    t.string "location_type"
    t.string "rdv_external_id"
    t.string "rdv_plan_external_id", null: false
    t.datetime "starts_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["dossier_id", "rdv_external_id"], name: "index_rdvs_on_dossier_id_and_rdv_external_id"
    t.index ["dossier_id", "starts_at"], name: "index_rdvs_on_dossier_id_and_starts_at"
    t.index ["dossier_id"], name: "index_rdvs_on_dossier_id"
    t.index ["instructeur_id"], name: "index_rdvs_on_instructeur_id"
  end

  create_table "re_instructed_mails", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "procedure_id", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["procedure_id"], name: "index_re_instructed_mails_on_procedure_id"
  end

  create_table "received_mails", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.integer "procedure_id"
    t.string "subject"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["procedure_id"], name: "index_received_mails_on_procedure_id"
  end

  create_table "referentiel_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.jsonb "option", default: {}, null: false
    t.bigint "referentiel_id", null: false
    t.datetime "updated_at", null: false
    t.index ["referentiel_id"], name: "index_referentiel_items_on_referentiel_id"
  end

  create_table "referentiels", force: :cascade do |t|
    t.jsonb "authentication_data", default: {}
    t.string "authentication_method"
    t.jsonb "autocomplete_configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "digest"
    t.string "headers", default: [], array: true
    t.string "hint"
    t.jsonb "last_response"
    t.string "mode"
    t.string "name", null: false
    t.string "test_data"
    t.string "type"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "refused_mails", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.integer "procedure_id"
    t.string "subject"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["procedure_id"], name: "index_refused_mails_on_procedure_id"
  end

  create_table "release_notes", force: :cascade do |t|
    t.string "categories", default: [], array: true
    t.datetime "created_at", null: false
    t.boolean "published", default: false, null: false
    t.date "released_on"
    t.datetime "updated_at", null: false
    t.index ["categories"], name: "index_release_notes_on_categories", using: :gin
    t.index ["published"], name: "index_release_notes_on_published"
    t.index ["released_on"], name: "index_release_notes_on_released_on"
  end

  create_table "safe_mailers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "forced_delivery_method"
    t.datetime "updated_at", null: false
  end

  create_table "services", force: :cascade do |t|
    t.bigint "administrateur_id"
    t.text "adresse"
    t.string "contact_link"
    t.datetime "created_at", precision: nil, null: false
    t.string "departement"
    t.string "email"
    t.jsonb "etablissement_infos", default: {}
    t.decimal "etablissement_lat", precision: 10, scale: 6
    t.decimal "etablissement_lng", precision: 10, scale: 6
    t.string "faq_link"
    t.text "horaires"
    t.string "nom", null: false
    t.string "organisme"
    t.text "other_contact_info"
    t.string "siret"
    t.string "telephone"
    t.string "type_organisme", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["administrateur_id", "nom"], name: "index_services_on_administrateur_id_and_nom", unique: true
    t.index ["administrateur_id"], name: "index_services_on_administrateur_id"
    t.index ["departement"], name: "index_services_on_departement"
  end

  create_table "stats", force: :cascade do |t|
    t.bigint "administrations_partenaires", default: 0
    t.datetime "created_at", null: false
    t.bigint "dossiers_brouillon", default: 0
    t.jsonb "dossiers_cumulative", default: "{}", null: false
    t.bigint "dossiers_depose_avant_30_jours", default: 0
    t.bigint "dossiers_deposes_entre_60_et_30_jours", default: 0
    t.bigint "dossiers_en_construction", default: 0
    t.bigint "dossiers_en_instruction", default: 0
    t.jsonb "dossiers_in_the_last_4_months", default: "{}", null: false
    t.bigint "dossiers_not_brouillon", default: 0
    t.bigint "dossiers_termines", default: 0
    t.datetime "updated_at", null: false
  end

  create_table "super_admins", id: :serial, force: :cascade do |t|
    t.integer "consumed_timestep"
    t.datetime "created_at", precision: nil
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_otp_secret"
    t.string "encrypted_otp_secret_iv"
    t.string "encrypted_otp_secret_salt"
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.boolean "otp_required_for_login"
    t.string "otp_secret"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil
    t.index ["email"], name: "index_super_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_super_admins_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_super_admins_on_unlock_token", unique: true
  end

  create_table "targeted_user_links", id: :uuid, default: -> { "public.gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "target_context", null: false
    t.bigint "target_model_id", null: false
    t.string "target_model_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["target_model_id"], name: "index_targeted_user_links_on_target_model_id"
    t.index ["user_id"], name: "index_targeted_user_links_on_user_id"
  end

  create_table "task_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.datetime "updated_at", null: false
  end

  create_table "task_records", id: false, force: :cascade do |t|
    t.string "version", null: false
  end

  create_table "traitements", force: :cascade do |t|
    t.string "browser_name"
    t.boolean "browser_supported"
    t.integer "browser_version"
    t.bigint "dossier_id"
    t.string "instructeur_email"
    t.string "motivation"
    t.datetime "processed_at", precision: nil
    t.bigint "revision_id"
    t.string "state"
    t.index ["dossier_id"], name: "index_traitements_on_dossier_id"
  end

  create_table "trusted_device_tokens", force: :cascade do |t|
    t.datetime "activated_at"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "instructeur_id"
    t.datetime "renewal_notified_at"
    t.string "token", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["activated_at", "renewal_notified_at"], name: "idx_on_activated_at_renewal_notified_at_ca000bc08e"
    t.index ["instructeur_id"], name: "index_trusted_device_tokens_on_instructeur_id"
    t.index ["token"], name: "index_trusted_device_tokens_on_token", unique: true
  end

  create_table "types_de_champ", id: :serial, force: :cascade do |t|
    t.jsonb "condition"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "libelle"
    t.boolean "mandatory", default: true
    t.text "nature"
    t.jsonb "options"
    t.boolean "private", default: false, null: false
    t.bigint "referentiel_id"
    t.bigint "stable_id"
    t.string "type_champ"
    t.datetime "updated_at", precision: nil
    t.index ["private"], name: "index_types_de_champ_on_private"
    t.index ["referentiel_id"], name: "index_types_de_champ_on_referentiel_id"
    t.index ["stable_id"], name: "index_types_de_champ_on_stable_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.datetime "announces_seen_at"
    t.datetime "blocked_at"
    t.text "blocked_reason"
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.boolean "email_unsubscribed", default: false, null: false
    t.datetime "email_verified_at"
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "inactive_close_to_expiration_notice_sent_at"
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.string "locale"
    t.datetime "locked_at", precision: nil
    t.string "loged_in_with_france_connect", default: "false"
    t.integer "preferred_domain"
    t.datetime "remember_created_at", precision: nil
    t.bigint "requested_merge_into_id"
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "siret"
    t.boolean "team_account", default: false
    t.text "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_sign_in_at"], name: "index_users_on_last_sign_in_at"
    t.index ["requested_merge_into_id"], name: "index_users_on_requested_merge_into_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unconfirmed_email"], name: "index_users_on_unconfirmed_email"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "without_continuation_mails", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.integer "procedure_id"
    t.string "subject"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["procedure_id"], name: "index_without_continuation_mails_on_procedure_id"
  end

  create_table "zone_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "designated_on", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "zone_id", null: false
    t.index ["zone_id"], name: "index_zone_labels_on_zone_id"
  end

  create_table "zones", force: :cascade do |t|
    t.string "acronym", null: false
    t.datetime "created_at", null: false
    t.string "label"
    t.string "tchap_hs", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["acronym"], name: "index_zones_on_acronym", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "administrateurs", "groupe_gestionnaires"
  add_foreign_key "administrateurs", "users"
  add_foreign_key "administrateurs_instructeurs", "administrateurs"
  add_foreign_key "administrateurs_instructeurs", "instructeurs"
  add_foreign_key "administrateurs_procedures", "administrateurs"
  add_foreign_key "administrateurs_procedures", "procedures"
  add_foreign_key "agent_connect_informations", "users"
  add_foreign_key "api_tokens", "administrateurs"
  add_foreign_key "archives_groupe_instructeurs", "archives"
  add_foreign_key "archives_groupe_instructeurs", "groupe_instructeurs"
  add_foreign_key "assign_tos", "groupe_instructeurs"
  add_foreign_key "attestation_templates", "procedures"
  add_foreign_key "attestations", "dossiers"
  add_foreign_key "avis", "dossiers"
  add_foreign_key "avis", "experts_procedures"
  add_foreign_key "batch_operations", "instructeurs"
  add_foreign_key "bulk_messages", "procedures"
  add_foreign_key "champs", "dossiers"
  add_foreign_key "champs", "etablissements"
  add_foreign_key "champs", "types_de_champ"
  add_foreign_key "closed_mails", "procedures"
  add_foreign_key "commentaires", "dossiers"
  add_foreign_key "commentaires", "experts"
  add_foreign_key "commentaires", "instructeurs"
  add_foreign_key "contact_forms", "users"
  add_foreign_key "contact_informations", "groupe_instructeurs"
  add_foreign_key "dossier_assignments", "dossiers"
  add_foreign_key "dossier_batch_operations", "batch_operations"
  add_foreign_key "dossier_batch_operations", "dossiers"
  add_foreign_key "dossier_corrections", "commentaires"
  add_foreign_key "dossier_corrections", "dossiers"
  add_foreign_key "dossier_labels", "dossiers"
  add_foreign_key "dossier_labels", "labels"
  add_foreign_key "dossier_notifications", "dossiers"
  add_foreign_key "dossier_notifications", "instructeurs"
  add_foreign_key "dossier_operation_logs", "bill_signatures"
  add_foreign_key "dossier_pending_responses", "commentaires"
  add_foreign_key "dossier_pending_responses", "dossiers"
  add_foreign_key "dossier_transfer_logs", "dossiers"
  add_foreign_key "dossiers", "batch_operations"
  add_foreign_key "dossiers", "dossier_transfers"
  add_foreign_key "dossiers", "dossiers", column: "parent_dossier_id"
  add_foreign_key "dossiers", "groupe_instructeurs"
  add_foreign_key "dossiers", "procedure_revisions", column: "revision_id"
  add_foreign_key "dossiers", "users"
  add_foreign_key "experts", "users"
  add_foreign_key "experts_procedures", "experts"
  add_foreign_key "experts_procedures", "procedures"
  add_foreign_key "export_templates", "groupe_instructeurs"
  add_foreign_key "exports", "export_templates"
  add_foreign_key "exports", "instructeurs"
  add_foreign_key "follows", "dossiers"
  add_foreign_key "follows", "instructeurs"
  add_foreign_key "france_connect_informations", "users"
  add_foreign_key "geo_areas", "champs"
  add_foreign_key "groupe_instructeurs", "procedures"
  add_foreign_key "initiated_mails", "procedures"
  add_foreign_key "instructeurs", "users"
  add_foreign_key "instructeurs_procedures", "instructeurs"
  add_foreign_key "instructeurs_procedures", "procedures"
  add_foreign_key "labels", "procedures"
  add_foreign_key "llm_rule_suggestion_items", "llm_rule_suggestions"
  add_foreign_key "llm_rule_suggestions", "procedure_revisions"
  add_foreign_key "merge_logs", "users"
  add_foreign_key "procedure_paths", "procedures"
  add_foreign_key "procedure_presentations", "assign_tos"
  add_foreign_key "procedure_revision_types_de_champ", "procedure_revision_types_de_champ", column: "parent_id"
  add_foreign_key "procedure_revision_types_de_champ", "procedure_revisions", column: "revision_id"
  add_foreign_key "procedure_revision_types_de_champ", "types_de_champ"
  add_foreign_key "procedure_revisions", "dossier_submitted_messages"
  add_foreign_key "procedure_revisions", "procedures"
  add_foreign_key "procedures", "groupe_instructeurs", column: "defaut_groupe_instructeur_id"
  add_foreign_key "procedures", "procedure_revisions", column: "draft_revision_id"
  add_foreign_key "procedures", "procedure_revisions", column: "published_revision_id"
  add_foreign_key "procedures", "services"
  add_foreign_key "procedures", "zones"
  add_foreign_key "rdv_connections", "instructeurs"
  add_foreign_key "rdvs", "dossiers"
  add_foreign_key "rdvs", "instructeurs"
  add_foreign_key "received_mails", "procedures"
  add_foreign_key "referentiel_items", "referentiels"
  add_foreign_key "refused_mails", "procedures"
  add_foreign_key "services", "administrateurs"
  add_foreign_key "targeted_user_links", "users"
  add_foreign_key "traitements", "dossiers"
  add_foreign_key "traitements", "procedure_revisions", column: "revision_id"
  add_foreign_key "trusted_device_tokens", "instructeurs"
  add_foreign_key "types_de_champ", "referentiels"
  add_foreign_key "users", "users", column: "requested_merge_into_id"
  add_foreign_key "without_continuation_mails", "procedures"
  add_foreign_key "zone_labels", "zones"
end
