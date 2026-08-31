# frozen_string_literal: true

RSpec.describe DossierStateConcern do
  include Logic

  let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs:, declarative_with_state:, auto_archive_on:) }
  let(:public_type_de_champs) do
    [
      { type: :text, stable_id: 90 },
      { type: :text, stable_id: 91 },
      { type: :piece_justificative, stable_id: 92, condition: ds_eq(constant(true), constant(false)) },
      { type: :piece_justificative, nature: 'titre_identite', stable_id: 93, condition: ds_eq(constant(true), constant(false)) },
      { type: :repetition, stable_id: 94, children: [{ type: :text, stable_id: 941 }, { type: :text, stable_id: 942 }] },
      { type: :repetition, stable_id: 95, children: [{ type: :text, stable_id: 951 }] },
      { type: :repetition, stable_id: 96, children: [{ type: :text, stable_id: 961 }], condition: ds_eq(constant(true), constant(false)) },
      { type: :text, stable_id: 97, condition: ds_eq(constant(true), constant(false)) },
      { type: :piece_justificative, nature: 'titre_identite', stable_id: 98 },
    ]
  end
  let(:auto_archive_on) { nil }
  let(:declarative_with_state) { nil }
  let(:dossier_state) { :brouillon }
  let(:dossier) do
    create(:dossier, dossier_state, :with_individual, :with_populated_champs, procedure:).tap do |dossier|
      procedure.draft_revision.remove_type_de_champ(91)
      procedure.draft_revision.remove_type_de_champ(95)
      procedure.draft_revision.remove_type_de_champ(942)
      procedure.publish_revision!(procedure.administrateurs.first)
      perform_enqueued_jobs
      dossier.reload
      champ_repetition = dossier.root_champs_public.find { _1.stable_id == 94 }
      row_id = champ_repetition.row_ids.first
      dossier.champ_data.filter(&:row?).find { _1.row_id == row_id }.touch(:discarded_at)
    end
  end

  describe 'submit brouillon' do
    it do
      expect(dossier.champ_data.size).to eq(20)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champ_data.filter { _1.row? && _1.discarded? }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(4)
      expect(dossier.champ_data.filter { _1.stable_id.in?([90, 92, 93, 97, 961, 951]) }.size).to eq(8)

      champ_text = dossier.root_champs_public.find { _1.stable_id == 90 }
      champ_text.update(value: '')

      dossier.passer_en_construction!
      dossier.reload

      expect(dossier.champ_data.size).to eq(7)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.row? && _1.discarded? }.size).to eq(0)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(0)
      expect(dossier.champ_data.filter { _1.stable_id.in?([90, 92, 93, 97, 961, 951]) && !(_1.blank? || !_1.visible?) }.size).to eq(0)
      expect(dossier.submitted_revision_id).to eq(dossier.revision_id)
    end

    context "when procedure is sva/svr or declarative" do
      before do
        procedure.defaut_groupe_instructeur.add_instructeurs(ids: create_list(:instructeur, 2).map(&:id))
      end

      it 'does not create notification when procedure is sva/svr', :slow do
        procedure.update!(sva_svr: { 'decision' => 'sva' }, declarative_with_state: nil)
        dossier.procedure.reload
        dossier.passer_en_construction!

        expect(DossierNotification.count).to eq(0)
      end

      it 'does not create notification when procedure is declarative', :slow do
        procedure.update!(declarative_with_state: "accepte", sva_svr: {})
        dossier.procedure.reload
        dossier.passer_en_construction!

        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe 'submit en construction' do
    let(:dossier_state) { :en_construction }

    it do
      expect(dossier.champ_data.size).to eq(20)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champ_data.filter { _1.row? && _1.discarded? }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(4)
      expect(dossier.champ_data.filter { _1.stable_id.in?([92, 93, 97, 961, 951]) }.size).to eq(7)

      dossier.usager_submit_en_construction!
      dossier.reload

      expect(dossier.champ_data.size).to eq(7)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.row? && _1.discarded? }.size).to eq(0)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(0)
      expect(dossier.champ_data.filter { _1.stable_id.in?([92, 93, 97, 961, 951]) && !(_1.blank? || !_1.visible?) }.size).to eq(0)
      expect(dossier.submitted_revision_id).to eq(dossier.revision_id)
    end

    context "when there are instructeurs wish to be notified" do
      let(:instructeur_follower) { create(:instructeur, followed_dossiers: [dossier]) }
      let(:instructeur_not_follower) { create(:instructeur) }
      let!(:instructeur_not_follower_procedure) { create(:instructeurs_procedure, instructeur: instructeur_not_follower, procedure:, display_dossier_modifie_notifications: 'all') }

      before do
        procedure.defaut_groupe_instructeur.add_instructeurs(ids: [instructeur_follower, instructeur_not_follower].map(&:id))
      end

      it "create dossier_modifie notification only for instructeur wish to be notified" do
        dossier.usager_submit_en_construction!

        expect(DossierNotification.count).to eq(2)

        expect(DossierNotification.distinct.pluck(:dossier_id)).to eq([dossier.id])
        expect(DossierNotification.pluck(:instructeur_id)).to match_array([instructeur_follower.id, instructeur_not_follower.id])
        expect(DossierNotification.distinct.pluck(:notification_type)).to eq(["dossier_modifie"])
      end
    end
  end

  describe 'AMI notifications' do
    before do
      allow(Ami::CreateNotificationService).to receive(:call)
    end

    it 'enqueues AMI notification after passer_en_construction' do
      dossier.after_commit_passer_en_construction
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after passer_en_instruction' do
      dossier.after_commit_passer_en_instruction({})
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after passer_automatiquement_en_instruction' do
      dossier.after_commit_passer_automatiquement_en_instruction
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after accepter' do
      dossier.after_commit_accepter({})
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after accepter_automatiquement' do
      dossier.after_commit_accepter_automatiquement
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after refuser' do
      dossier.after_commit_refuser({})
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after refuser_automatiquement' do
      dossier.after_commit_refuser_automatiquement
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after classer_sans_suite' do
      dossier.after_commit_classer_sans_suite({})
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end

    it 'enqueues AMI notification after repasser_en_instruction' do
      dossier.after_commit_repasser_en_instruction({})
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: :repasser_en_instruction)
    end

    it 'enqueues AMI notification after repasser_en_construction' do
      dossier.after_commit_repasser_en_construction
      expect(Ami::CreateNotificationService).to have_received(:call).with(dossier:, trigger: :dossier_state_change, state: nil)
    end
  end

  describe 'accepter' do
    let(:dossier_state) { :en_instruction }

    it do
      expect(dossier.champ_data.size).to eq(20)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.accepter!(motivation: 'test')
      dossier.reload

      expect(dossier.champ_data.size).to eq(17)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
    end

    context "when dossier has attente_avis notification" do
      let(:instructeur) { create(:instructeur) }
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

      it "destroy the notification" do
        dossier.accepter!(motivation: 'test')

        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe 'refuser' do
    let(:dossier_state) { :en_instruction }

    it do
      expect(dossier.champ_data.size).to eq(20)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.refuser!(motivation: 'test')
      dossier.reload

      expect(dossier.champ_data.size).to eq(17)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
    end

    context "when dossier has attente_avis notification" do
      let(:instructeur) { create(:instructeur) }
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

      it "destroy the notification" do
        dossier.refuser!(motivation: 'test')

        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe 'classer_sans_suite' do
    let(:dossier_state) { :en_instruction }

    it '', :slow do
      expect(dossier.champ_data.size).to eq(20)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.classer_sans_suite!(motivation: 'test')
      dossier.reload

      expect(dossier.champ_data.size).to eq(17)
      expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
    end

    context "when dossier has an attestation from a previous acceptation" do
      let!(:attestation) { create(:attestation, dossier:) }

      it "destroys the attestation" do
        expect(dossier.attestation).to be_present

        dossier.classer_sans_suite!(motivation: 'test')
        dossier.reload

        expect(dossier.attestation).to be_nil
      end
    end

    context "when dossier has attente_avis notification" do
      let(:instructeur) { create(:instructeur) }
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

      it "destroy the notification" do
        dossier.classer_sans_suite!(motivation: 'test')

        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe 'automatiquement' do
    let(:dossier_state) { :en_construction }

    describe 'accepter' do
      let(:declarative_with_state) { Dossier.states.fetch(:accepte) }

      it do
        expect(dossier.champ_data.size).to eq(20)
        expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
        expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

        dossier.accepter_automatiquement!
        dossier.reload

        expect(dossier.champ_data.size).to eq(17)
        expect(dossier.champ_data.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
        expect(dossier.champ_data.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
      end
    end

    describe 'en_instruction' do
      context "when dossier has a dossier_depose notification" do
        let(:auto_archive_on) { 1.day.from_now }
        let(:instructeur) { create(:instructeur) }
        let!(:notification) { create(:dossier_notification, dossier:, instructeur:) }

        it "destroy the notification" do
          travel_to(2.days.from_now)
          dossier.passer_automatiquement_en_instruction!

          expect(DossierNotification.count).to eq(0)
        end
      end
    end
  end

  describe 'declarative combined notifications' do
    let(:procedure) { create(:procedure, :published, :for_individual, declarative_with_state:) }
    let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:) }
    let(:deliveries) { ActionMailer::Base.deliveries }
    let(:decision_date) { I18n.l(dossier.reload.processed_at.to_date, format: :short) }

    # Chaque sujet court est un préfixe strict de son combiné : on les compare
    # en entier, sinon « a bien été déposé » matche aussi le combiné.
    let(:depose_subject) { "Votre dossier n° #{dossier.id} a bien été déposé (#{procedure.libelle})" }
    let(:passe_en_instruction_subject) { "Votre dossier n° #{dossier.id} va être examiné (#{procedure.libelle})" }
    let(:accepte_subject) { "Votre dossier n° #{dossier.id} a été accepté (#{procedure.libelle})" }

    before { stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake') }

    def deposer_dossier
      perform_enqueued_jobs(only: PriorizedMailDeliveryJob) { dossier.passer_en_construction! }
    end

    def body_of(mail) = (mail.html_part || mail).body.to_s

    def deliveries_to(dossier) = deliveries.filter { it.to.include?(dossier.user_email_for(:notification)) }

    context 'when the procedure is not declarative' do
      let(:declarative_with_state) { nil }

      it 'sends the proof of receipt alone, and posts it once in the messagerie' do
        expect { deposer_dossier }
          .to change { deliveries.size }.by(1)
          .and change { dossier.commentaires.count }.by(1)

        expect(deliveries.last.subject).to eq(depose_subject)
        expect(dossier.commentaires.last.body).to include('a bien été déposé')
      end
    end

    context 'when the procedure is declarative en instruction' do
      let(:declarative_with_state) { Dossier.states.fetch(:en_instruction) }

      it 'sends the combined email alone, and posts it once in the messagerie' do
        expect { deposer_dossier }
          .to change { deliveries.size }.by(1)
          .and change { dossier.commentaires.count }.by(1)

        expect(dossier.reload).to be_en_instruction
        expect(deliveries.last.subject).to include('a bien été déposé et va être examiné')
        expect(body_of(deliveries.last)).to include('pris en charge')
        expect(dossier.commentaires.last.body).to include('a bien été déposé et va être examiné', 'pris en charge')
      end

      context 'and it stays on the legacy emails' do
        before { procedure.update!(combined_declarative_email: false) }

        it 'sends both historical emails, and posts them both in the messagerie' do
          expect { deposer_dossier }
            .to change { deliveries.size }.by(2)
            .and change { dossier.commentaires.count }.by(2)

          expect(deliveries.last(2).map(&:subject))
            .to contain_exactly(depose_subject, passe_en_instruction_subject)
        end
      end

      context 'and a dossier put back en construction is auto archived' do
        let(:procedure) { create(:procedure, :published, :for_individual, declarative_with_state:, auto_archive_on: 1.day.from_now) }
        let!(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, declarative_triggered_at: 1.day.ago) }

        it 'sends and posts the passage en instruction template, not a second proof of receipt' do
          travel_to(2.days.from_now)

          expect { perform_enqueued_jobs(only: PriorizedMailDeliveryJob) { AutoArchiveProcedureDossiersJob.perform_now(procedure) } }
            .to change { deliveries.size }.by(1)
            .and change { dossier.commentaires.count }.by(1)

          expect(dossier.reload).to be_en_instruction
          expect(deliveries.last.subject).to eq(passe_en_instruction_subject)
          expect(dossier.commentaires.last.body).to include('a bien été reçu', 'pris en charge')
          expect(dossier.commentaires.last.body).not_to include('déposé')
        end
      end
    end

    context 'when the procedure is declarative accepte' do
      let(:declarative_with_state) { Dossier.states.fetch(:accepte) }

      it 'sends the combined email alone, with the decision date substituted in the email and in the messagerie' do
        expect { deposer_dossier }
          .to change { deliveries.size }.by(1)
          .and change { dossier.commentaires.count }.by(1)

        expect(dossier.reload).to be_accepte
        expect(deliveries.last.subject).to include('a bien été déposé et a été accepté')
        expect(body_of(deliveries.last)).to include("a été accepté le #{decision_date}")
        expect(dossier.commentaires.last.body).to include('a bien été déposé', "a été accepté le #{decision_date}")
      end

      context 'and it stays on the legacy emails' do
        before { procedure.update!(combined_declarative_email: false) }

        it 'sends both historical emails, and posts them both in the messagerie' do
          expect { deposer_dossier }
            .to change { deliveries.size }.by(2)
            .and change { dossier.commentaires.count }.by(2)

          expect(deliveries.last(2).map(&:subject))
            .to contain_exactly(depose_subject, accepte_subject)
        end
      end

      context 'and a dossier left en construction is auto archived' do
        let(:procedure) { create(:procedure, :published, :for_individual, declarative_with_state:, auto_archive_on: 1.day.from_now) }
        let!(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }

        it 'sends and posts the passage en instruction template, the decision not being taken' do
          travel_to(2.days.from_now)

          expect { perform_enqueued_jobs(only: PriorizedMailDeliveryJob) { AutoArchiveProcedureDossiersJob.perform_now(procedure) } }
            .to change { deliveries.size }.by(1)
            .and change { dossier.commentaires.count }.by(1)

          expect(dossier.reload).to be_en_instruction
          expect(deliveries.last.subject).to eq(passe_en_instruction_subject)
          expect(dossier.commentaires.last.body).to include('a bien été reçu', 'pris en charge')
          expect(dossier.commentaires.last.body).not_to include('accepté')
        end
      end

      context 'and the automatic transition is caught up by the cron' do
        let!(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }

        it 'sends the combined email, with the decision date substituted' do
          expect {
            perform_enqueued_jobs(only: [ProcessStalledDeclarativeDossierJob, PriorizedMailDeliveryJob]) do
              Cron::StalledDeclarativeProceduresJob.perform_now
            end
          }.to change { deliveries_to(dossier).size }.by(1)
            .and change { dossier.commentaires.count }.by(1)

          expect(dossier.reload).to be_accepte
          expect(deliveries_to(dossier).last.subject).to include('a bien été déposé et a été accepté')
          expect(body_of(deliveries_to(dossier).last)).to include("a été accepté le #{decision_date}")
          expect(dossier.commentaires.last.body).to include('a bien été déposé', "a été accepté le #{decision_date}")
        end
      end

      context 'and the procedure uses the accusé de lecture' do
        let(:procedure) { create(:procedure, :published, :for_individual, :accuse_lecture, declarative_with_state:) }

        it 'sends the combined email, which reveals the decision' do
          expect { deposer_dossier }.to change { deliveries.size }.by(1)
          expect(deliveries.last.subject).to include('a bien été déposé et a été accepté')
        end
      end
    end

    context 'when a non declarative procedure uses the accusé de lecture' do
      let(:procedure) { create(:procedure, :published, :for_individual, :sva, :accuse_lecture) }
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: Date.current) }

      it 'still sends the accusé de lecture, and keeps the decision out of the messagerie' do
        expect { perform_enqueued_jobs(only: PriorizedMailDeliveryJob) { dossier.accepter_automatiquement! } }
          .to change { deliveries.size }.by(1)
          .and change { dossier.commentaires.count }.by(1)

        expect(deliveries.last.subject)
          .to eq(I18n.t('notification_mailer.send_accuse_lecture_notification.subject', dossier_id: dossier.id, libelle: procedure.libelle.truncate_words(50)))
        expect(dossier.commentaires.last.body).to include('décision sur votre dossier a été rendue')
      end
    end
  end

  describe 'auto purge piece justificative after decision' do
    let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

    before { allow(ClamavService).to receive(:safe_file?).and_return(true) }

    context 'when piece_justificative with titre_identite nature' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champ_data.first }

      it 'destroys champ on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end
    end

    context 'when nature is titre_identite' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champ_data.first }

      it 'destroys champ on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end
    end

    context 'when pj_auto_purge is enabled' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative, pj_auto_purge: '1' }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champ_data.first }

      it 'destroys champ on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end
    end

    context 'when standard piece justificative' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champ_data.first }

      it 'keeps attachments on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be true
      end
    end
  end

  describe 'submit brouillon with pre_rempli champ' do
    context 'when pre_rempli champ is hidden (pre_rempli_hidden: "1")' do
      let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :pre_rempli, pre_rempli_hidden: "1", stable_id: 100 }]) }
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:) }

      before do
        champ = dossier.root_champs_public.find { _1.stable_id == 100 }
        champ.update(value: "valeur cachée")
      end

      it 'preserves the hidden pre_rempli value after submission' do
        dossier.passer_en_construction!
        dossier.reload

        champ = dossier.root_champs_public.find { _1.stable_id == 100 }
        expect(champ.value).to eq("valeur cachée")
      end
    end

    context 'when pre_rempli champ is visible but condition is false' do
      let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :pre_rempli, stable_id: 101, condition: ds_eq(constant(true), constant(false)) }]) }
      let(:dossier) { create(:dossier, :brouillon, :with_individual, procedure:) }

      before do
        champ = dossier.root_champs_public.find { _1.stable_id == 101 }
        champ.update(value: "valeur conditionnelle")
      end

      it 'clears the value because the champ is not visible' do
        dossier.passer_en_construction!
        dossier.reload

        champ = dossier.root_champs_public.find { _1.stable_id == 101 }
        expect(champ.value).to be_nil
      end
    end
  end

  describe '#clear_france_connect_champs_piece_justificatives (after user submits a dossier or modifications)' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :quotient_familial }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }

    subject { dossier.send(:clear_france_connect_champs_piece_justificatives!) }

    context "when data have been fetched and the user has confirmed its accuracy, but he has uploaded an attachment" do
      before do
        champ.update(value: 'true', external_state: 'fetched')
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
      end

      it 'deletes the associated attachment' do
        subject
        expect(champ.reload.piece_justificative_file).not_to be_attached
      end
    end

    context "when data have been fetched and the user user does not confirm its accuracy, so he has uploaded an attachment" do
      before do
        champ.update(value: 'false', external_state: 'fetched')
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
      end

      it 'does not delete the associated attachment' do
        subject
        expect(champ.reload.piece_justificative_file).to be_attached
      end
    end

    context "when data have not been fetched, so the user has uploaded an attachment" do
      before do
        champ.update(external_state: 'idle')
        champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
      end

      it 'does not delete the associated attachment' do
        subject
        expect(champ.reload.piece_justificative_file).to be_attached
      end
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
