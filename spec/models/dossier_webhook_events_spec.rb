# frozen_string_literal: true

describe 'Webhook events emission', type: :model do
  let(:procedure) { procedures.individual }
  let(:webhook) { webhooks.default }
  let(:instructeur) { instructeurs.default }

  before do
    Flipper.enable(:webhooks_api, procedure)
    webhook.update!(event_types: Webhook::EVENT_TYPES)
  end

  def events_for(dossier, event_type)
    procedure.webhook_events.where(dossier_id: dossier.id, event_type:)
  end

  it 'raises at the emit site on an event type missing from EVENT_TYPES' do
    expect { dossiers.en_construction.emit_webhook_event(:dossier_acepte) }
      .to raise_error(ArgumentError, /dossier_acepte/)
  end

  it 'emits on dossier state transitions' do
    dossier = dossiers.en_construction

    expect { dossier.passer_en_instruction!(instructeur:) }
      .to change { events_for(dossier, "dossier_en_instruction").count }.by(1)

    expect { dossier.accepter!(instructeur:, motivation: "ok") }
      .to change { events_for(dossier, "dossier_accepte").count }.by(1)

    expect { dossier.repasser_en_instruction!(instructeur:) }
      .to change { events_for(dossier, "dossier_repasse_en_instruction").count }.by(1)
  end

  it 'emits when the dossier is hidden from administration' do
    dossier = dossiers.refuse

    expect { dossier.hide_and_keep_track!(instructeur, :instructeur_request) }
      .to change { events_for(dossier, "dossier_supprime").count }.by(1)
  end

  it 'emits on new commentaire, but not on system commentaires' do
    dossier = dossiers.en_construction

    expect { CommentaireService.create!(instructeur, dossier, body: "Bonjour") }
      .to change { events_for(dossier, "message_cree").count }.by(1)

    expect { CommentaireService.create!(CONTACT_EMAIL, dossier, body: "system") }
      .not_to change { events_for(dossier, "message_cree").count }
  end

  it 'emits avis_repondu when an avis receives its answer, not on later edits' do
    dossier = dossiers.en_instruction

    expect { avis.pending.submit_answer(answer: "Avis favorable.") }
      .to change { events_for(dossier, "avis_repondu").count }.by(1)

    expect { avis.pending.submit_answer(answer: "Avis favorable, complété.") }
      .not_to change { events_for(dossier, "avis_repondu").count }
  end

  it 'refuses a blank answer, keeping the avis_repondu emission for the real one' do
    dossier = dossiers.en_instruction
    pending_avis = avis.pending

    expect { expect(pending_avis.submit_answer(answer: "")).to be(false) }
      .not_to change { events_for(dossier, "avis_repondu").count }
    expect(pending_avis.errors[:answer]).to be_present
    expect(pending_avis.reload.answer).to be_nil

    expect { pending_avis.submit_answer(answer: "Avis favorable.") }
      .to change { events_for(dossier, "avis_repondu").count }.by(1)
  end

  it 'emits on label changes, once even when repeated' do
    dossier = dossiers.en_construction
    label = procedure.labels.create!(name: "À relancer", color: "green_emeraude")

    expect { 2.times { dossier.add_label(label) } }
      .to change { events_for(dossier, "dossier_label_ajoute").count }.by(1)

    expect { dossier.remove_label(label) }
      .to change { events_for(dossier, "dossier_label_supprime").count }.by(1)

    expect { dossier.remove_label(label) }
      .not_to change { events_for(dossier, "dossier_label_supprime").count }
  end

  it 'emits when a groupe instructeur is reassigned' do
    dossier = dossiers.en_construction
    other_groupe = procedure.groupe_instructeurs.create!(label: "Autre groupe")

    expect { dossier.assign_to_groupe_instructeur(other_groupe, DossierAssignment.modes.fetch(:manual), instructeur) }
      .to change { events_for(dossier, "groupe_instructeur_change").count }.by(1)
  end

  it 'emits dossier_modifie before the groupe_instructeur_change a re-routing triggers' do
    dossier = dossiers.en_construction
    other_groupe = procedure.groupe_instructeurs.create!(label: "Autre groupe")
    allow(RoutingEngine).to receive(:compute) do |routed|
      routed.assign_to_groupe_instructeur(other_groupe, DossierAssignment.modes.fetch(:auto))
    end

    dossier.usager_submit_en_construction!

    expect(procedure.webhook_events.where(dossier_id: dossier.id).order(:id).pluck(:event_type))
      .to eq(["dossier_modifie", "groupe_instructeur_change"])
  end

  it 'does not emit when the feature flag is disabled' do
    Flipper.disable(:webhooks_api, procedure)
    dossier = dossiers.en_construction

    expect { dossier.passer_en_instruction!(instructeur:) }
      .not_to change { procedure.webhook_events.count }
  end

  it 'does not emit dossier_supprime when a brouillon is hidden' do
    dossier = dossiers.brouillon

    expect { dossier.hide_and_keep_track!(dossier.user, :user_request) }
      .not_to change { events_for(dossier, "dossier_supprime").count }
  end

  it 'emits dossier_supprime only once when the dossier is hidden twice' do
    dossier = dossiers.refuse
    dossier.hide_and_keep_track!(instructeur, :instructeur_request)

    expect { dossier.hide_and_keep_track!(dossier.user, :user_request) }
      .not_to change { events_for(dossier, "dossier_supprime").count }
  end

  it 'emits dossier_restaure when a hidden dossier is restored' do
    dossier = dossiers.refuse
    dossier.hide_and_keep_track!(instructeur, :instructeur_request)

    expect { dossier.restore(instructeur) }
      .to change { events_for(dossier, "dossier_restaure").count }.by(1)
  end

  it 'emits dossier_restaure when an expired-hidden dossier is restored' do
    dossier = dossiers.refuse
    dossier.hide_and_keep_track!(:automatic, :expired)

    expect { dossier.extend_conservation_and_restore(1.month, instructeur) }
      .to change { events_for(dossier, "dossier_restaure").count }.by(1)
    expect(dossier.reload.hidden_by_expired_at).to be_nil
    expect(dossier.hidden_by_reason).to be_nil
  end

  describe 'procedure removal' do
    it 'emits nothing on removal nor on restore, leaving the webhooks untouched' do
      dossier = dossiers.en_construction
      administrateur = procedure.administrateurs.first

      expect { procedure.discard_and_keep_track!(administrateur) }
        .not_to change { procedure.webhook_events.count }

      expect(webhook.reload.enabled).to be(true)
      expect(dossier.reload.hidden_by_administration_at).to be_present
      expect(procedure.reload).to be_discarded

      expect { procedure.restore(administrateur) }
        .not_to change { procedure.webhook_events.count }

      expect(procedure.reload).to be_kept
      expect(dossier.reload.hidden_by_administration_at).to be_nil
      expect(webhook.reload.enabled).to be(true)
    end
  end

  it 'emits correction_demandee after the dossier moved back en construction' do
    dossier = dossiers.en_instruction
    commentaire = CommentaireService.build(instructeur, dossier, body: "Merci de corriger")

    expect { dossier.flag_as_pending_correction!(commentaire) }
      .to change { events_for(dossier, "correction_demandee").count }.by(1)
    expect(dossier.reload).to be_en_construction

    expect(procedure.webhook_events.where(dossier_id: dossier.id).order(:id).pluck(:event_type))
      .to eq(["message_cree", "dossier_repasse_en_construction", "correction_demandee"])
  end

  describe 'ordering on auto-transitions' do
    let(:declarative_procedure) { create(:procedure, :published, :for_individual, declarative_with_state:) }
    let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure: declarative_procedure) }

    before do
      Flipper.enable(:webhooks_api, declarative_procedure)
      Webhook.create!(procedure: declarative_procedure, url: "https://exemple.fr/hook", event_types: Webhook::EVENT_TYPES)
    end

    context 'declarative accepte' do
      let(:declarative_with_state) { 'accepte' }

      it 'emits dossier_depose before the dossier_accepte it triggers' do
        dossier.passer_en_construction!

        expect(declarative_procedure.webhook_events.order(:id).pluck(:event_type))
          .to eq(["dossier_depose", "dossier_accepte"])
      end
    end

    context 'declarative en instruction' do
      let(:declarative_with_state) { 'en_instruction' }

      it 'emits dossier_depose before the dossier_en_instruction it triggers' do
        dossier.passer_en_construction!

        expect(declarative_procedure.webhook_events.order(:id).pluck(:event_type))
          .to eq(["dossier_depose", "dossier_en_instruction"])
      end
    end
  end

  it 'does not fan out label events when the label itself is destroyed' do
    dossier = dossiers.en_construction
    label = procedure.labels.create!(name: "Éphémère", color: "green_emeraude")
    dossier.dossier_labels.create!(label:)

    expect { label.destroy! }
      .not_to change { events_for(dossier, "dossier_label_supprime").count }
  end
end
