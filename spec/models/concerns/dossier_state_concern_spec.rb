# frozen_string_literal: true

# One `describe` per transition entry point (AASM event or submit method),
# asserting the model-level side effects of the `after_*` / `after_commit_*`
# hooks: attributes and traitements, operation log, commentaire, usager mails,
# AMI, instructeur badges, experts, attestation, champ housekeeping. Guards
# (`can_*`) are covered in dossier_spec; the champ cleanup rules themselves in
# dossier_champs_concern_spec.
RSpec.describe DossierStateConcern do
  include ActionView::Helpers::SanitizeHelper
  include Logic

  before_all { seed "cases/sva" }

  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:last_operation) { dossier.dossier_operation_logs.last }
  let(:justificatif_file) do
    { io: StringIO.new('Hello World'), filename: 'hello.txt', metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE } }
  end

  before do
    freeze_time
    allow(Ami::CreateNotificationService).to receive(:call)
  end

  def notifications(dossier, type) = DossierNotification.where(dossier:, notification_type: type)

  # NotificationMailer.send_<state>_notification(dossier) all enqueue the
  # parameterized #send_notification: that is what the job queue sees.
  def have_enqueued_usager_notification(dossier, state)
    have_enqueued_mail(NotificationMailer, :send_notification).with(params: { dossier:, state: }, args: [])
  end

  def for_tiers!(dossier) = dossier.update_columns(for_tiers: true, mandataire_first_name: 'John', mandataire_last_name: 'Doe')

  def push_user_buffer_change(dossier)
    stable_id = dossier.revision.public_root_type_de_champs.first.stable_id
    dossier.with_update_stream(dossier.user) do
      dossier.public_champ_for_update(stable_id.to_s, updated_by: dossier.user.email).assign_attributes(value: 'modifié')
    end
    dossier.save!
    expect(dossier.champ_data.where(stream: Dossier::USER_BUFFER_STREAM)).to be_present
  end

  shared_examples 'notifies the usager' do |state, ami_state: nil, tiers_options: {}|
    it "enqueues the #{state} mail" do
      expect { subject }.to have_enqueued_usager_notification(dossier, state)
    end

    it 'does not notify a tiers' do
      expect { subject }.not_to have_enqueued_mail(NotificationMailer, :send_notification_for_tiers)
    end

    it 'enqueues the AMI notification' do
      subject
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: ami_state)
    end

    context 'when the dossier is filled for a tiers' do
      before { for_tiers!(dossier) }

      it 'also notifies the tiers' do
        expect { subject }.to have_enqueued_mail(NotificationMailer, :send_notification_for_tiers).with(dossier, **tiers_options)
      end
    end
  end

  shared_examples 'can skip the usager notification' do
    context 'with disable_notification' do
      let(:disable_notification) { true }

      before { for_tiers!(dossier) }

      it 'enqueues no mail and no AMI notification' do
        expect { subject }.not_to have_enqueued_mail(NotificationMailer)
        expect(Ami::CreateNotificationService).not_to have_received(:call)
      end
    end
  end

  shared_examples 'a decision' do |event, state:|
    let(:dossier) { dossiers.en_instruction }
    let(:justificatif) { nil }
    let(:disable_notification) { false }

    subject(:decide) do
      dossier.public_send(:"#{event}!", instructeur:, motivation: 'motivation', justificatif:, disable_notification:)
      dossier.reload
    end

    it 'records the decision' do
      decide

      expect(dossier.state).to eq(state)
      expect(dossier.processed_at).to eq(Time.current)
      expect(dossier.expired_at).to eq(dossier.expiration_date)
      expect(dossier.motivation).to eq('motivation')
      expect(dossier.justificatif_motivation).not_to be_attached
      expect(dossier.traitement.state).to eq(state)
      expect(dossier.traitement.motivation).to eq('motivation')
      expect(dossier.traitement.instructeur_email).to eq(instructeur.email)
      expect(dossier.traitement.processed_at).to eq(Time.current)
    end

    it 'logs the operation with the dossier as subject' do
      decide

      expect(last_operation.operation).to eq(event.to_s)
      expect(last_operation.automatic_operation?).to be(false)
      expect(last_operation.data['author']['email']).to eq(instructeur.email)
      expect(last_operation.data['subject']).to be_present
    end

    it 'creates the commentaire for the state' do
      expect { decide }.to change { dossier.commentaires.count }.by(1)
    end

    context 'with a justificatif' do
      let(:justificatif) { justificatif_file }

      it 'attaches it' do
        decide
        expect(dossier.justificatif_motivation).to be_attached
      end
    end

    include_examples 'notifies the usager', state
    include_examples 'can skip the usager notification'

    context 'when the procedure sends an accusé de lecture' do
      before { procedure.update!(accuse_lecture: true) }

      it 'enqueues the accusé de lecture mail instead' do
        expect { decide }.to have_enqueued_mail(NotificationMailer, :send_accuse_lecture_notification).with(dossier)
        expect { decide }.not_to have_enqueued_mail(NotificationMailer, :send_notification)
      end
    end

    describe 'experts' do
      let(:pending_avis) { avis.pending }

      it 'does not send the decision to an expert without an answer or access' do
        expect { decide }.not_to have_enqueued_mail(ExpertMailer, :send_dossier_decision)
      end

      it 'sends the decision to experts who answered and may access it' do
        pending_avis.update!(answer: 'Avis favorable')
        experts_procedures.default.update!(allow_decision_access: true)

        expect { decide }.to have_enqueued_mail(ExpertMailer, :send_dossier_decision).with(pending_avis)
      end
    end

    it 'removes the attente_avis badge' do
      create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis)

      expect { decide }.to change { notifications(dossier, :attente_avis).count }.from(1).to(0)
    end

    it 'cleans the champs after instruction' do
      expect(dossier).to receive(:clean_champs_after_instruction!)
      decide
    end
  end

  shared_examples 'generates the attestation' do |kind|
    it 'enqueues the attestation generation when the procedure has a published template' do
      create(:attestation_template, procedure:, kind:, state: :published)

      expect { subject }.to have_enqueued_job(AttestationPdfGenerationJob).with(dossier)
    end

    it 'enqueues nothing without a template' do
      expect { subject }.not_to have_enqueued_job(AttestationPdfGenerationJob)
    end
  end

  describe '#passer_en_construction!' do
    let(:dossier) { dossiers.brouillon }

    subject(:passer_en_construction) do
      dossier.passer_en_construction!
      dossier.reload
    end

    it 'deposits the dossier' do
      passer_en_construction

      expect(dossier.state).to eq('en_construction')
      expect(dossier.depose_at).to eq(Time.current)
      expect(dossier.en_construction_at).to eq(Time.current)
      expect(dossier.expired_at).to be_nil
      expect(dossier.conservation_extension).to eq(0.days)
      expect(dossier.submitted_revision_id).to eq(dossier.revision_id)
      expect(dossier.groupe_instructeur).to eq(procedure.defaut_groupe_instructeur)
      expect(dossier.traitement.state).to eq('en_construction')
      expect(dossier.traitement.processed_at).to eq(Time.current)
    end

    it 'creates the commentaire for the state' do
      expect { passer_en_construction }.to change { dossier.commentaires.count }.by(1)
    end

    it 'updates the procedure dossiers count' do
      expect(dossier.procedure).to receive(:compute_dossiers_count)
      passer_en_construction
    end

    it 'cleans the champs and reindexes the search terms' do
      expect(dossier).to receive(:clean_champs_after_submit!)
      expect { passer_en_construction }.to have_enqueued_job(DossierIndexSearchTermsJob).with(dossier)
    end

    it 'keeps the first en_construction_at as depose_at through later transitions' do
      passer_en_construction
      travel 1.hour
      dossier.passer_en_instruction!(instructeur:)
      travel 1.hour
      dossier.repasser_en_construction!(instructeur:)

      expect(dossier.traitements.size).to eq(3)
      expect(dossier.traitements.first.processed_at).to eq(2.hours.ago)
      expect(dossier.depose_at).to eq(2.hours.ago)
      expect(dossier.en_construction_at).to eq(Time.current)
    end

    include_examples 'notifies the usager', 'en_construction'

    describe 'instructeur notifications' do
      it 'creates a dossier_depose badge for the groupe instructeurs' do
        expect { passer_en_construction }.to change { notifications(dossier, :dossier_depose).count }.from(0).to(1)
        expect(notifications(dossier, :dossier_depose).sole.instructeur).to eq(instructeur)
      end

      it 'does not email instructeurs without the instant email preference' do
        expect { passer_en_construction }.not_to have_enqueued_mail(DossierMailer, :notify_new_dossier_depose_to_instructeur)
      end

      it 'emails instructeurs who asked for an instant email' do
        create(:instructeurs_procedure, instructeur:, procedure:, instant_email_new_dossier: true)

        expect { passer_en_construction }.to have_enqueued_mail(DossierMailer, :notify_new_dossier_depose_to_instructeur).with(dossier, instructeur.email)
      end

      context 'when the procedure is declarative' do
        before { procedure.update!(declarative_with_state: 'en_instruction') }

        it 'passes the dossier en instruction and creates no dossier_depose badge' do
          passer_en_construction

          expect(dossier).to be_en_instruction
          expect(notifications(dossier, :dossier_depose)).to be_empty
        end
      end

      context 'when the procedure is sva' do
        let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure: procedures.sva) }

        it 'passes the dossier en instruction and creates no dossier_depose badge' do
          passer_en_construction

          expect(dossier).to be_en_instruction
          expect(dossier.sva_svr_decision_on).to be_present
          expect(notifications(dossier, :dossier_depose)).to be_empty
        end
      end
    end

    context 'when the procedure routes its dossiers' do
      let(:gi_libelle) { 'Paris' }
      let!(:procedure) do
        create(:procedure,
               public_type_de_champs: [
                 { type: :drop_down_list, libelle: 'Votre ville', options: [gi_libelle, 'Lyon', 'Marseille'] },
                 { type: :text, libelle: 'Un champ texte' },
               ])
      end
      let!(:drop_down_tdc) { procedure.draft_revision.type_de_champs.first }
      let(:dossier) { create(:dossier, :brouillon, user: users.usager, procedure:, groupe_instructeur: nil) }
      let(:gi) { create(:groupe_instructeur, routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant(gi_libelle))) }

      before do
        procedure.groupe_instructeurs = [gi]
        procedure.defaut_groupe_instructeur = gi
        procedure.save!
        procedure.toggle_routing
        dossier.champ_data.first.value = gi_libelle
        dossier.save!
      end

      it 'assigns the groupe instructeur computed by the RoutingEngine' do
        passer_en_construction
        expect(dossier.groupe_instructeur).to eq(gi)
      end
    end
  end

  describe '#usager_submit_en_construction!' do
    let(:dossier) { dossiers.en_construction }

    subject(:submit) do
      dossier.usager_submit_en_construction!
      dossier.reload
    end

    it 'records a correction traitement on the merged checkpoint' do
      push_user_buffer_change(dossier)
      submit

      expect(dossier.traitement.event).to eq(:depose_correction_usager)
      expect(dossier.traitement.processed_at).to eq(Time.current)
      expect(dossier.traitement.checkpoint).to be_present
      expect(dossier.submitted_revision_id).to eq(dossier.revision_id)
      expect(dossier.champ_data.where(stream: Dossier::USER_BUFFER_STREAM)).to be_empty
      expect(dossier.traitement.changed_columns.map(&:value)).to eq(['modifié'])
    end

    it 'resolves the pending correction' do
      create(:dossier_correction, dossier:)

      expect { submit }.to change { dossier.pending_correction? }.from(true).to(false)
    end

    it 'cleans the champs' do
      expect(dossier).to receive(:clean_champs_after_submit!)
      submit
    end

    it 'enqueues no usager mail' do
      expect { submit }.not_to have_enqueued_mail(NotificationMailer)
    end

    describe 'dossier_modifie badge' do
      let(:instructeur_follower) { create(:instructeur, followed_dossiers: [dossier]) }
      let(:instructeur_not_follower) { create(:instructeur) }
      let!(:instructeur_not_follower_procedure) { create(:instructeurs_procedure, instructeur: instructeur_not_follower, procedure:, display_dossier_modifie_notifications: 'all') }

      before do
        procedure.defaut_groupe_instructeur.add_instructeurs(ids: [instructeur_follower, instructeur_not_follower].map(&:id))
      end

      it 'is created only for instructeurs who wish to be notified' do
        submit

        expect(notifications(dossier, :dossier_modifie).pluck(:instructeur_id)).to match_array([instructeur_follower.id, instructeur_not_follower.id])
      end
    end
  end

  describe '#instructeur_submit_en_construction!' do
    let(:dossier) { dossiers.en_construction }

    subject(:submit) do
      dossier.instructeur_submit_en_construction!(instructeur:, motivation: 'Correction de la saisie')
      dossier.reload
    end

    it 'records an instructeur correction traitement and explains it in a commentaire' do
      expect { submit }.to change { dossier.commentaires.count }.by(1)

      expect(dossier.traitement.event).to eq(:depose_correction_instructeur)
      expect(dossier.traitement.instructeur_email).to eq(instructeur.email)
      expect(dossier.traitement.motivation).to eq('Correction de la saisie')
      expect(dossier.commentaires.last.instructeur).to eq(instructeur)
    end

    it 'does not touch submitted_revision_id nor notify the usager' do
      expect { submit }.not_to change { dossier.submitted_revision_id }
      expect { submit }.not_to have_enqueued_mail(NotificationMailer)
    end
  end

  describe '#passer_en_instruction!' do
    let(:dossier) { dossiers.en_construction }
    let(:disable_notification) { false }

    subject(:passer_en_instruction) do
      dossier.passer_en_instruction!(instructeur:, disable_notification:)
      dossier.reload
    end

    it 'starts the instruction' do
      passer_en_instruction

      expect(dossier.state).to eq('en_instruction')
      expect(dossier.en_instruction_at).to eq(Time.current)
      expect(dossier.expired_at).to be_nil
      expect(dossier.conservation_extension).to eq(0.days)
      expect(dossier.followers_instructeurs).to include(instructeur)
      expect(dossier.traitement.state).to eq('en_instruction')
      expect(dossier.traitement.instructeur_email).to eq(instructeur.email)
      expect(dossier.traitement.processed_at).to eq(Time.current)
    end

    it 'keeps the first en_instruction_at through later transitions' do
      passer_en_instruction
      travel 1.hour
      dossier.repasser_en_construction!(instructeur:)
      travel 1.hour
      dossier.passer_en_instruction!(instructeur:)

      expect(dossier.traitements.size).to eq(4)
      expect(dossier.traitements.en_construction.first.processed_at).to eq(dossier.depose_at)
      expect(dossier.traitements.en_instruction.first.processed_at).to eq(2.hours.ago)
      expect(dossier.en_instruction_at).to eq(Time.current)
    end

    it 'logs the operation' do
      passer_en_instruction

      expect(last_operation.operation).to eq('passer_en_instruction')
      expect(last_operation.automatic_operation?).to be(false)
      expect(last_operation.data['author']['email']).to eq(instructeur.email)
      expect(last_operation.data['executed_at']).to eq(last_operation.executed_at.iso8601)
    end

    it 'resolves the pending correction and creates the commentaire for the state' do
      correction = create(:dossier_correction, dossier:) # a correction comes with its own commentaire

      expect { passer_en_instruction }.to change { dossier.commentaires.count }.by(1)

      expect(dossier.pending_correction?).to be(false)
      expect(correction.reload.resolved_at).to be_present

      email_template = procedure.email_template_for(dossier.state)
      expect(dossier.commentaires.last.body).to include(sanitize(email_template.subject_for_dossier(dossier)), sanitize(email_template.body_for_dossier(dossier)))
    end

    it 'drops the pending buffer streams' do
      push_user_buffer_change(dossier)

      expect { passer_en_instruction }.to change { dossier.champ_data.where(stream: Dossier::USER_BUFFER_STREAM).count }.to(0)
    end

    include_examples 'notifies the usager', 'en_instruction'
    include_examples 'can skip the usager notification'

    it 'removes the dossier_expirant and dossier_depose badges' do
      create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_expirant)
      create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_depose)

      passer_en_instruction

      expect(notifications(dossier, :dossier_expirant)).to be_empty
      expect(notifications(dossier, :dossier_depose)).to be_empty
    end
  end

  describe '#passer_automatiquement_en_instruction!' do
    context 'via a declarative procedure' do
      let(:dossier) { create(:dossier, :en_construction, :with_declarative_en_instruction, procedure:) }

      subject(:process) do
        dossier.process_declarative!
        dossier.reload
      end

      it 'passes the dossier en instruction without a follower' do
        process

        expect(dossier).to be_en_instruction
        expect(dossier.en_instruction_at).to eq(Time.current)
        expect(dossier.declarative_triggered_at).to eq(Time.current)
        expect(dossier.conservation_extension).to eq(0.days)
        expect(dossier.expired_at).to be_nil
        expect(dossier.followers_instructeurs).to be_empty
        expect(dossier.traitement.instructeur_email).to be_nil
      end

      it 'logs an automatic operation' do
        process

        expect(last_operation.operation).to eq('passer_en_instruction')
        expect(last_operation.automatic_operation?).to be(true)
        expect(last_operation.data['author']).to be_nil
      end

      it 'creates the commentaire for the state' do
        expect { process }.to change { dossier.commentaires.count }.by(1)
      end

      include_examples 'notifies the usager', 'en_instruction'

      it 'removes the dossier_depose badge' do
        create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_depose)

        expect { process }.to change { notifications(dossier, :dossier_depose).count }.to(0)
      end

      it 'drops the pending buffer streams like a manual passage' do
        pending 'after_passer_automatiquement_en_instruction does not reset the buffer streams'
        push_user_buffer_change(dossier)

        expect { dossier.passer_automatiquement_en_instruction! }.to change { dossier.champ_data.where(stream: Dossier::USER_BUFFER_STREAM).count }.to(0)
      end
    end

    context 'via a sva procedure' do
      let(:procedure) { procedures.sva }
      let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now) }
      let(:sva_svr_decision_on) { SVASVRDecisionDateCalculatorService.new(dossier, procedure).decision_date }

      subject(:process) do
        dossier.process_sva_svr!
        dossier.reload
      end

      it 'passes the dossier en instruction with the recomputed decision date' do
        process

        expect(dossier).to be_en_instruction
        expect(dossier.followers_instructeurs).to be_empty
        expect(dossier.sva_svr_decision_on).to eq(sva_svr_decision_on)
        expect(last_operation.operation).to eq('passer_en_instruction')
        expect(last_operation.automatic_operation?).to be(true)
        expect(last_operation.data['subject']).to be_present
      end

      context 'when the dossier was submitted before sva was enabled' do
        let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, depose_at: 10.days.ago) }

        it 'leaves the dossier en construction' do
          process

          expect(dossier.sva_svr_decision_on).to be_nil
          expect(dossier).to be_en_construction
        end
      end
    end
  end

  describe '#repasser_en_construction!' do
    let(:dossier) { dossiers.en_instruction }

    subject(:repasser_en_construction) do
      dossier.repasser_en_construction!(instructeur:)
      dossier.reload
    end

    it 'sends the dossier back en construction' do
      repasser_en_construction

      expect(dossier.state).to eq('en_construction')
      expect(dossier.en_construction_at).to eq(Time.current)
      expect(dossier.depose_at).to be < Time.current
      expect(dossier.expired_at).to be_nil
      expect(dossier.conservation_extension).to eq(0.days)
      expect(dossier.traitement.state).to eq('en_construction')
      expect(dossier.traitement.instructeur_email).to eq(instructeur.email)
    end

    it 'logs the operation' do
      repasser_en_construction

      expect(last_operation.operation).to eq('repasser_en_construction')
      expect(last_operation.data['author']['email']).to eq(instructeur.email)
    end

    it 'notifies AMI but sends no mail' do
      expect { repasser_en_construction }.not_to have_enqueued_mail(NotificationMailer)
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'recreates the traitements missing from the timeline' do
      dossier.traitements.destroy_all
      dossier.update_columns(en_construction_at: 2.days.ago, en_instruction_at: 1.day.ago, depose_at: nil)

      repasser_en_construction

      expect(dossier.traitements.map { [it.state, it.processed_at] }).to eq([
        ['en_construction', 2.days.ago],
        ['en_instruction', 1.day.ago],
        ['en_construction', Time.current],
      ])
      expect(dossier.depose_at).to eq(2.days.ago)
    end
  end

  describe '#accepter!' do
    include_examples 'a decision', :accepter, state: 'accepte'
    include_examples 'generates the attestation', :acceptation
  end

  describe '#refuser!' do
    include_examples 'a decision', :refuser, state: 'refuse'
    include_examples 'generates the attestation', :refus
  end

  describe '#classer_sans_suite!' do
    include_examples 'a decision', :classer_sans_suite, state: 'sans_suite'

    it 'destroys the attestation of a previous acceptation' do
      create(:attestation, dossier:)

      expect { subject }.to change { dossier.attestation }.to(nil)
    end
  end

  describe '#accepter_automatiquement!' do
    let!(:attestation_template) { create(:attestation_template, procedure:, kind: :acceptation, state: :published) }

    subject(:accepter) do
      perform_enqueued_jobs(only: AttestationPdfGenerationJob) { dossier.accepter_automatiquement! }
      dossier.reload
    end

    context 'via a declarative procedure' do
      let(:dossier) { create(:dossier, :en_construction, :with_individual, :with_declarative_accepte, procedure:) }

      it 'accepts the dossier' do
        accepter

        expect(dossier).to be_accepte
        expect(dossier.motivation).to be_nil
        expect(dossier.en_instruction_at).to eq(Time.current)
        expect(dossier.processed_at).to eq(Time.current)
        expect(dossier.expired_at).to eq(dossier.expiration_date)
        expect(dossier.declarative_triggered_at).to eq(Time.current)
        expect(dossier.sva_svr_decision_triggered_at).to be_nil
        expect(last_operation.operation).to eq('accepter')
        expect(last_operation.automatic_operation?).to be(true)
        expect(dossier.attestation).to be_present
      end

      it 'creates the commentaire for the state' do
        expect { accepter }.to change { dossier.commentaires.count }.by(1)
      end

      include_examples 'notifies the usager', 'accepte'

      it 'cleans the champs after instruction' do
        expect(dossier).to receive(:clean_champs_after_instruction!)
        accepter
      end
    end

    context 'via a sva procedure' do
      let(:procedure) { procedures.sva }
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.current, en_instruction_at: DateTime.new(2021, 5, 1, 12)) }

      it 'accepts the dossier' do
        accepter

        expect(dossier).to be_accepte
        expect(dossier.motivation).to be_nil
        expect(dossier.en_instruction_at).to eq(DateTime.new(2021, 5, 1, 12))
        expect(dossier.processed_at).to eq(Time.current)
        expect(dossier.declarative_triggered_at).to be_nil
        expect(dossier.sva_svr_decision_triggered_at).to eq(Time.current)
        expect(last_operation.operation).to eq('accepter')
        expect(last_operation.automatic_operation?).to be(true)
        expect(dossier.attestation).to be_present
        expect(dossier.commentaires.count).to eq(1)
      end
    end
  end

  describe '#refuser_automatiquement!' do
    let(:procedure) { procedures.svr }
    let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.current, en_instruction_at: DateTime.new(2021, 5, 1, 12)) }

    subject(:refuser) do
      dossier.refuser_automatiquement!
      dossier.reload
    end

    it 'refuses the dossier with the svr motivation' do
      refuser

      expect(dossier).to be_refuse
      expect(dossier.en_instruction_at).to eq(DateTime.new(2021, 5, 1, 12))
      expect(dossier.processed_at).to eq(Time.current)
      expect(dossier.expired_at).to eq(dossier.expiration_date)
      expect(dossier.declarative_triggered_at).to be_nil
      expect(dossier.sva_svr_decision_triggered_at).to eq(Time.current)
      expect(dossier.motivation).to include('dans le délai imparti')
      expect(dossier.traitement.motivation).to eq(dossier.motivation)
      expect(last_operation.operation).to eq('refuser')
      expect(last_operation.automatic_operation?).to be(true)
      expect(dossier.attestation).to be_nil
      expect(dossier.commentaires.count).to eq(1)
    end

    it 'translates the motivation in the usager locale' do
      dossier.user.update!(locale: 'en')
      refuser
      expect(dossier.motivation).to include('within the time limit')
    end

    include_examples 'notifies the usager', 'refuse'
  end

  describe '#repasser_en_instruction!' do
    let(:dossier) { dossiers.refuse }
    let(:disable_notification) { false }

    before do
      create(:attestation_template, :refus, procedure:, state: :published)
      AttestationPdfGenerationJob.perform_now(dossier)
      dossier.justificatif_motivation.attach(justificatif_file)
      dossier.update!(archived: true, hidden_by_user_at: 1.day.ago, termine_close_to_expiration_notice_sent_at: Time.current, sva_svr_decision_on: 1.day.ago)
    end

    subject(:repasser_en_instruction) do
      dossier.repasser_en_instruction!(instructeur:, disable_notification:)
      dossier.reload
    end

    it 'reopens the instruction and clears the decision' do
      expect(dossier.attestation).to be_present

      repasser_en_instruction

      expect(dossier.state).to eq('en_instruction')
      expect(dossier.en_instruction_at).to eq(Time.current)
      expect(dossier.expired_at).to be_nil
      expect(dossier.conservation_extension).to eq(0.days)
      expect(dossier.archived).to be(false)
      expect(dossier.hidden_by_user_at).to be_nil
      expect(dossier.termine_close_to_expiration_notice_sent_at).to be_nil
      expect(dossier.motivation).to be_nil
      expect(dossier.justificatif_motivation).not_to be_attached
      expect(dossier.attestation).to be_nil
      expect(dossier.sva_svr_decision_on).to be_nil
      expect(dossier.traitement.state).to eq('en_instruction')
      expect(dossier.traitement.instructeur_email).to eq(instructeur.email)
    end

    it 'logs the operation and creates the commentaire' do
      expect { repasser_en_instruction }.to change { dossier.commentaires.count }.by(1)

      expect(last_operation.operation).to eq('repasser_en_instruction')
      expect(last_operation.data['author']['email']).to eq(instructeur.email)
    end

    include_examples 'notifies the usager', 'repasser_en_instruction', ami_state: :repasser_en_instruction, tiers_options: { repasser_en_instruction: true }
    include_examples 'can skip the usager notification'

    it 'removes the dossier_expirant badge' do
      create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_expirant)

      expect { repasser_en_instruction }.to change { notifications(dossier, :dossier_expirant).count }.to(0)
    end

    it 'rebases the dossier later' do
      expect(dossier).to receive(:rebase_later)
      repasser_en_instruction
    end
  end

  describe 'carte static map rendering' do
    let(:carte_procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :carte }, { type: :text }]) }
    let(:carte_dossier) { create(:dossier, dossier_state, procedure: carte_procedure) }
    let(:carte_champ) { carte_dossier.champ_data.find(&:carte?) }

    before { carte_champ.update(geo_areas: [build(:geo_area, :selection_utilisateur, :polygon)]) }

    context 'on dépôt' do
      let(:dossier_state) { :brouillon }

      it 'renders the map once the dossier is submitted' do
        expect { carte_dossier.after_commit_passer_en_construction }
          .to have_enqueued_job(RenderCarteChampJob).with(carte_champ).exactly(:once)
      end
    end

    context 'on submitting changes' do
      let(:dossier_state) { :en_construction }

      it 'renders the map again' do
        expect { carte_dossier.usager_submit_en_construction! }
          .to have_enqueued_job(RenderCarteChampJob).with(carte_champ)
      end

      it 'renders the map when an instructeur submits changes' do
        instructeur = create(:instructeur)
        carte_procedure.defaut_groupe_instructeur.add_instructeurs(ids: [instructeur.id])

        expect { carte_dossier.instructeur_submit_en_construction!(instructeur:) }
          .to have_enqueued_job(RenderCarteChampJob).with(carte_champ)
      end

      # A carte champ left empty has nothing to render: no point calling IGN to
      # find out the geometry is missing.
      it 'skips champs without geometry' do
        carte_champ.geo_areas.destroy_all

        expect { carte_dossier.reload.usager_submit_en_construction! }
          .not_to have_enqueued_job(RenderCarteChampJob)
      end

      # ... but an image rendered before the geometry was removed must not
      # survive the submission that removed it.
      context 'when the geometry is removed after a first render' do
        before { carte_champ.attach_static_map(StringIO.new('map-bytes'), digest: 'abc') }

        it 'purges the stale map when the usager submits' do
          carte_champ.geo_areas.destroy_all

          expect do
            perform_enqueued_jobs(only: RenderCarteChampJob) { carte_dossier.reload.usager_submit_en_construction! }
          end.to change { carte_champ.reload.static_map.attached? }.from(true).to(false)
        end

        it 'purges the stale map when an instructeur submits' do
          instructeur = create(:instructeur)
          carte_procedure.defaut_groupe_instructeur.add_instructeurs(ids: [instructeur.id])
          carte_champ.geo_areas.destroy_all

          expect do
            perform_enqueued_jobs(only: RenderCarteChampJob) { carte_dossier.reload.instructeur_submit_en_construction!(instructeur:) }
          end.to change { carte_champ.reload.static_map.attached? }.from(true).to(false)
        end
      end
    end
  end
end
