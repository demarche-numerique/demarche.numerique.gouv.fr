# frozen_string_literal: true

describe Instructeurs::DossiersController, type: :controller do
  render_views

  let(:instructeur) { create(:instructeur) }
  let(:administration) { create(:administration) }
  let(:instructeurs) { [instructeur] }
  let(:types_de_champ_public) { [] }
  let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: instructeurs, types_de_champ_public:) }
  let(:procedure_accuse_lecture) { create(:procedure, :published, :for_individual, :accuse_lecture, :new_administrateur, instructeurs: instructeurs) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure) }
  let(:dossier_accuse_lecture) { create(:dossier, :en_construction, :with_individual, procedure: procedure_accuse_lecture) }
  let(:dossier_for_tiers) { create(:dossier, :en_construction, :for_tiers_with_notification, procedure: procedure) }
  let(:dossier_for_tiers_without_notif) { create(:dossier, :en_construction, :for_tiers_without_notification, procedure: procedure) }
  let(:fake_justificatif) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

  before { sign_in(instructeur.user) }

  describe '#send_to_instructeurs' do
    let(:mail) { double("mail") }

    before do
      allow(mail).to receive(:deliver_later)

      allow(InstructeurMailer)
        .to receive(:send_dossier)
        .with(instructeur, dossier, recipient)
        .and_return(mail)

      post(
        :send_to_instructeurs,
        params: {
          recipients: [recipient.id],
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          statut: 'a-suivre',
        }
      )
    end

    context 'when the recipient belongs to the dossier groupe instructeur' do
      let(:recipient) { instructeur }

      it do
        expect(InstructeurMailer).to have_received(:send_dossier)
        expect(response).to redirect_to(personnes_impliquees_instructeur_dossier_url)
        expect(recipient.followed_dossiers).to include(dossier)
      end
    end

    context 'when the recipient is random' do
      let(:recipient) { create(:instructeur) }

      it do
        expect(InstructeurMailer).not_to have_received(:send_dossier)
        expect(response).to redirect_to(personnes_impliquees_instructeur_dossier_url)
        expect(recipient.followed_dossiers).not_to include(dossier)
      end
    end
  end

  describe '#follow' do
    let(:batch_operation) {}

    subject do
      travel(1.minute)
      batch_operation
      patch :follow, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
    end

    it do
      subject
      expect(instructeur.followed_dossiers).to match([dossier])
      expect(flash.notice).to eq('Dossier suivi')
      expect(response).to redirect_to(instructeur_procedure_path(dossier.procedure))
    end

    it "changes the updated_at" do
      expect { subject }.to change { dossier.reload.updated_at }
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }

      it do
        subject
        expect(instructeur.followed_dossiers).to eq([])
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#unfollow' do
    let(:batch_operation) {}
    before { instructeur.followed_dossiers << dossier }

    subject do
      travel(1.minute)
      batch_operation
      patch :unfollow, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
    end

    it do
      subject
      expect(instructeur.followed_dossiers).to match([])
      expect(flash.notice).to eq("Vous ne suivez plus le dossier n° #{dossier.id}")
      expect(response).to redirect_to(instructeur_procedure_path(dossier.procedure))
    end

    it "changes the updated_at" do
      expect { subject }.to change { dossier.reload.updated_at }
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }

      it do
        subject
        expect(instructeur.followed_dossiers).to eq([dossier])
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#archive' do
    let(:batch_operation) {}
    before do
      batch_operation
      patch :archive, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
      dossier.reload
      instructeur.follow(dossier)
    end

    it do
      expect(dossier.archived).to eq(true)
      expect(response).to redirect_to(instructeur_procedure_path(dossier.procedure))
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect(dossier.archived).to eq(false)
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#unarchive' do
    let(:batch_operation) {}
    before do
      batch_operation
      dossier.update(archived: true)
      patch :unarchive, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
    end

    it do
      expect(dossier.reload.archived).to eq(false)
      expect(response).to redirect_to(instructeur_procedure_path(dossier.procedure))
    end

    context 'with dossier in batch_operation' do
      let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect(dossier.reload.archived).to eq(true)
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#passer_en_instruction' do
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let(:batch_operation) {}
    let(:notification) {}

    before do
      batch_operation
      notification
      sign_in(instructeur.user)
      post :passer_en_instruction, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream
    end

    it do
      expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
      expect(instructeur.follow?(dossier)).to be true
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('header-top')
    end

    context 'when the dossier has already been put en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

      it 'warns about the error' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Le dossier est déjà en&nbsp;instruction.')
      end
    end

    context 'when the dossier has already been closed' do
      let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

      it 'doesn’t change the dossier state' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:accepte))
      end

      it 'warns about the error' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Le dossier est en ce moment accepté&nbsp;: il n’est pas possible de le passer en&nbsp;instruction.')
      end
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }

      it do
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end

    context "when dossier is expirant with a notification" do
      let(:notification) { create(:dossier_notification, dossier:, notification_type: :dossier_expirant) }

      it 'destroys notification' do
        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe '#repasser_en_construction' do
    let(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }
    let(:batch_operation) {}
    before do
      batch_operation
      sign_in(instructeur.user)
      post :repasser_en_construction,
        params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' },
        format: :turbo_stream
    end

    it do
      expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_construction))
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('header-top')
    end

    context 'when the dossier has already been put en_construction' do
      let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

      it 'warns about the error' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_construction))
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Le dossier est déjà en&nbsp;construction.')
      end
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect(dossier.reload.state).to eq('en_instruction')
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#repasser_en_instruction' do
    let(:dossier) { create(:dossier, :refuse, procedure: procedure) }
    let(:batch_operation) {}
    let(:notification) {}
    let(:current_user) { instructeur.user }

    before do
      sign_in current_user
      batch_operation
      notification
      post :repasser_en_instruction,
      params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' },
      format: :turbo_stream
    end

    context 'when the dossier is refuse' do
      it do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('header-top')
      end
    end

    context 'when the dossier has already been put en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

      it 'warns about the error' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Le dossier est déjà en&nbsp;instruction.')
      end
    end

    context 'when the dossier is accepte' do
      let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

      it 'it is possible to go back to en_instruction as instructeur' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the dossier is done and the user delete it' do
      let!(:dossier) { create(:dossier, :accepte, procedure: procedure, user: current_user, hidden_by_user_at: Time.zone.now) }

      it 'reveals the dossier' do
        expect(dossier.reload.state).to eq(Dossier.states.fetch(:en_instruction))
        expect(dossier.reload.hidden_by_user_at).to be_nil
      end
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect(dossier.reload.state).to eq('refuse')
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end

    context "when dossier is expirant with a notification" do
      let(:notification) { create(:dossier_notification, dossier:, notification_type: :dossier_expirant) }

      it 'destroys notification' do
        expect(DossierNotification.count).to eq(0)
      end
    end
  end

  describe '#terminer' do
    context "with refuser" do
      before do
        dossier.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)
      end

      context 'simple refusal' do
        subject { post :terminer, params: { process_action: "refuser", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'change state to refuse' do
          subject

          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:refuse))
          expect(dossier.justificatif_motivation).to_not be_attached
        end

        it 'Notification email is sent' do
          expect(NotificationMailer).to receive(:send_refuse_notification)
            .with(dossier).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          subject
        end

        it 'creates a commentaire' do
          expect { subject }.to change { Commentaire.count }.by(1)
        end
      end

      context 'refusal with a justificatif' do
        subject { post :terminer, params: { process_action: "refuser", procedure_id: procedure.id, dossier_id: dossier.id, dossier: { justificatif_motivation: fake_justificatif }, statut: 'a-suivre' }, format: :turbo_stream }

        it 'attachs a justificatif' do
          subject

          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:refuse))
          expect(dossier.justificatif_motivation).to be_attached
        end

        it { expect(subject.body).to include('header-top') }
      end

      context 'when the dossier does not have any attestation' do
        it 'Notification email is sent' do
          subject { post :terminer, params: { process_action: "refuser", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }
          subject
        end
      end

      context 'when the dossier has an attestation' do
        before do
          attestation = Attestation.new
          allow(attestation).to receive(:pdf).and_return(double(read: 'pdf', size: 2.megabytes, attached?: false))
          allow(attestation).to receive(:pdf_url).and_return('http://some_document_url')
          allow_any_instance_of(Dossier).to receive(:build_attestation).and_return(attestation)
        end

        subject { post :terminer, params: { process_action: "refuser", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'The instructeur is sent back to the dossier page' do
          subject
          expect(response.body).to include('header-top')
        end

        context 'and the dossier has already an attestation' do
          it 'should not crash' do
            dossier.attestation = Attestation.new
            dossier.save
            subject
            expect(response.body).to include('header-top')
          end
        end
      end

      context 'when the attestation template uses the motivation field' do
        let(:emailable) { false }
        let(:template) { create(:attestation_template, kind: :refus) }
        let(:procedure) { create(:procedure, :published, :for_individual, attestation_refus_template: template, instructeurs: [instructeur]) }

        subject do
          post :terminer, params: {
            process_action: "refuser",
            procedure_id: procedure.id,
            dossier_id: dossier.id,
            dossier: { motivation: "Non" },
            statut: 'a-suivre',
          }, format: :turbo_stream
        end

        before do
          expect_any_instance_of(AttestationTemplate)
            .to receive(:attestation_for)
            .with(have_attributes(motivation: "Non"))
        end

        it { subject }
      end

      context 'with dossier in batch_operation' do
        let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
        subject { post :terminer, params: { process_action: "refuser", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

        it do
          expect { subject }.not_to change { dossier.reload.state }
          is_expected.to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        end
        it 'flashes message' do
          subject
          expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
        end
      end
    end

    context "with for_tiers" do
      before do
        dossier_for_tiers.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)
      end
      context 'without continuation' do
        subject { post :terminer, params: { process_action: "classer_sans_suite", procedure_id: procedure.id, dossier_id: dossier_for_tiers.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'Notification email is sent' do
          expect(NotificationMailer).to receive(:send_sans_suite_notification)
            .with(dossier_for_tiers).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          expect(NotificationMailer).to receive(:send_notification_for_tiers)
            .with(dossier_for_tiers).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          subject
        end

        it '2 emails are sent' do
          expect { perform_enqueued_jobs { subject } }.to change { ActionMailer::Base.deliveries.count }.by(2)
        end
      end
    end

    context "with for_tiers_without_notif" do
      before do
        dossier_for_tiers_without_notif.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)
      end
      context 'without continuation' do
        subject { post :terminer, params: { process_action: "classer_sans_suite", procedure_id: procedure.id, dossier_id: dossier_for_tiers_without_notif.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'Notification email is sent' do
          expect(NotificationMailer).to receive(:send_sans_suite_notification)
            .with(dossier_for_tiers_without_notif).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          expect(NotificationMailer).to receive(:send_notification_for_tiers)
            .with(dossier_for_tiers_without_notif).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          subject
        end

        it 'only one email is sent' do
          expect { perform_enqueued_jobs { subject } }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end
    end

    context "with accuse de lecture procedure" do
      before do
        dossier_accuse_lecture.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)
      end
      context 'with classer_sans_suite' do
        subject { post :terminer, params: { process_action: "classer_sans_suite", procedure_id: procedure_accuse_lecture.id, dossier_id: dossier_accuse_lecture.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'Notification accuse de lecture email is sent and not the others' do
          expect(NotificationMailer).to receive(:send_accuse_lecture_notification)
            .with(dossier_accuse_lecture).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          expect(NotificationMailer).not_to receive(:send_sans_suite_notification)
            .with(dossier_accuse_lecture)

          subject
        end

        it { expect(subject.body).to include('header-top') }

        it 'creates a commentaire' do
          expect { subject }.to change { Commentaire.count }.by(1)
          expect(dossier_accuse_lecture.commentaires.last.body).to eq("<p>Bonjour,</p><p>Nous vous informons qu’une décision sur votre dossier a été rendue.</p>Cordialement,<br>#{procedure_accuse_lecture.service.nom}")
        end
      end
    end

    context "with classer_sans_suite" do
      before do
        dossier.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)
      end
      context 'without attachment' do
        subject { post :terminer, params: { process_action: "classer_sans_suite", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

        it 'change state to sans_suite' do
          subject

          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:sans_suite))
          expect(dossier.justificatif_motivation).to_not be_attached
        end

        it 'Notification email is sent' do
          expect(NotificationMailer).to receive(:send_sans_suite_notification)
            .with(dossier).and_return(NotificationMailer)
          expect(NotificationMailer).to receive(:deliver_later)

          expect(NotificationMailer).not_to receive(:send_notification_for_tiers)
            .with(dossier)

          subject
        end

        it { expect(subject.body).to include('header-top') }
      end

      context 'with attachment' do
        subject { post :terminer, params: { process_action: "classer_sans_suite", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre', dossier: { justificatif_motivation: fake_justificatif } }, format: :turbo_stream }

        it 'change state to sans_suite' do
          subject

          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:sans_suite))
          expect(dossier.justificatif_motivation).to be_attached
        end

        it { expect(subject.body).to include('header-top') }
      end
    end

    context "with accepter" do
      before do
        dossier.passer_en_instruction!(instructeur: instructeur)
        sign_in(instructeur.user)

        expect(NotificationMailer).to receive(:send_accepte_notification)
          .with(dossier)
          .and_return(NotificationMailer)

        expect(NotificationMailer).to receive(:deliver_later)
      end

      subject { post :terminer, params: { process_action: "accepter", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

      it 'change state to accepte' do
        subject

        dossier.reload
        expect(dossier.state).to eq(Dossier.states.fetch(:accepte))
        expect(dossier.justificatif_motivation).to_not be_attached
      end

      context 'when the dossier does not have any attestation' do
        it 'Notification email is sent' do
          subject
        end
      end

      context 'when the dossier has an attestation' do
        before do
          attestation = Attestation.new
          allow(attestation).to receive(:pdf).and_return(double(read: 'pdf', size: 2.megabytes, attached?: false))
          allow(attestation).to receive(:pdf_url).and_return('http://some_document_url')

          allow_any_instance_of(Dossier).to receive(:build_attestation).and_return(attestation)
        end

        it 'The instructeur is sent back to the dossier page' do
          expect(subject.body).to include('header-top')
        end

        context 'and the dossier has already an attestation' do
          it 'should not crash' do
            dossier.attestation = Attestation.new
            dossier.save
            expect(subject.body).to include('header-top')
          end
        end
      end

      context 'when the attestation template uses the motivation field' do
        let(:emailable) { false }
        let(:template) { create(:attestation_template) }
        let(:procedure) { create(:procedure, :published, :for_individual, attestation_acceptation_template: template, instructeurs: [instructeur]) }

        subject do
          post :terminer, params: {
            process_action: "accepter",
            procedure_id: procedure.id,
            dossier_id: dossier.id,
            dossier: { motivation: "Yallah" },
            statut: 'a-suivre',
          }, format: :turbo_stream
        end

        before do
          expect_any_instance_of(AttestationTemplate)
            .to receive(:attestation_for)
            .with(have_attributes(motivation: "Yallah"))
        end

        it { subject }
      end

      context 'with an attachment' do
        subject { post :terminer, params: { process_action: "accepter", procedure_id: procedure.id, dossier_id: dossier.id, dossier: { justificatif_motivation: fake_justificatif }, statut: 'a-suivre' }, format: :turbo_stream }

        it 'change state to accepte' do
          subject

          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:accepte))
          expect(dossier.justificatif_motivation).to be_attached
        end

        it { expect(subject.body).to include('header-top') }
      end
    end

    context 'when related etablissement is still in degraded_mode' do
      let(:procedure) { create(:procedure, :published, for_individual: false, instructeurs: instructeurs) }
      let(:dossier) { create(:dossier, :en_instruction, :with_entreprise, procedure: procedure, as_degraded_mode: true) }

      subject { post :terminer, params: { process_action: "accepter", procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }, format: :turbo_stream }

      context "with accepter" do
        it 'warns about the error' do
          subject
          dossier.reload
          expect(dossier.state).to eq(Dossier.states.fetch(:en_instruction))

          expect(response).to have_http_status(:ok)
          expect(response.body).to match(/Les données relatives au SIRET .+ de le passer en accepté/)
        end
      end
    end

    context 'when a dossier is already closed' do
      let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

      before { allow(dossier).to receive(:after_accepter) }

      subject { post :terminer, params: { process_action: "accepter", procedure_id: procedure.id, dossier_id: dossier.id, dossier: { justificatif_motivation: fake_justificatif }, statut: 'a-suivre' }, format: :turbo_stream }

      it 'does not close it again' do
        subject

        expect(dossier).not_to have_received(:after_accepter)
        expect(dossier.state).to eq(Dossier.states.fetch(:accepte))

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Le dossier est déjà accepté.')
      end
    end
  end

  describe '#pending_correction' do
    let(:message) { 'do that' }
    let(:justificatif) { nil }
    let(:reason) { nil }

    subject do
      post :pending_correction, params: {
        procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre',
        dossier: { motivation: message, justificatif_motivation: justificatif },
        reason:,
      }, format: :turbo_stream
    end

    before do
      sign_in(instructeur.user)
      expect(controller.current_instructeur).to receive(:mark_tab_as_seen).with(dossier, :messagerie)
    end

    context "dossier en instruction sends an email to user" do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }

      it { expect { subject }.to have_enqueued_mail(DossierMailer, :notify_pending_correction) }
    end

    context "dossier en instruction" do
      let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure: procedure) }

      before { subject }

      it 'pass en_construction and create a pending correction' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('en attente de correction')

        expect(dossier.reload).to be_en_construction
        expect(dossier).to be_pending_correction
        expect(dossier.corrections.last).to be_dossier_incorrect
      end

      it 'create a comment with text body' do
        expect(dossier.commentaires.last.body).to eq("do that")
        expect(dossier.commentaires.last).to be_flagged_pending_correction
      end

      context 'flagged as incomplete' do
        let(:reason) { 'incomplete' }

        it 'create a correction of incomplete reason' do
          expect(dossier.corrections.last).to be_dossier_incomplete
        end
      end

      context 'with an attachment' do
        let(:justificatif) { fake_justificatif }

        it 'attach file to comment' do
          expect(dossier.commentaires.last.piece_jointe).to be_attached
        end
      end

      context 'with an invalid comment / attachment' do
        let(:justificatif) { Rack::Test::UploadedFile.new(Rails.root.join('Gemfile.lock'), 'text/lock') }

        it 'does not save anything' do
          expect(dossier.reload).not_to be_pending_correction
          expect(dossier.commentaires.count).to eq(0)
          expect(response.body).to include('pas d’un type accepté')
        end
      end

      context 'with an empty message' do
        let(:message) { '' }

        it 'requires a message' do
          expect(dossier.reload).not_to be_pending_correction
          expect(dossier.commentaires.count).to eq(0)
          expect(response.body).to include('Vous devez préciser')
        end
      end

      context 'dossier already having pending corrections' do
        before do
          create(:dossier_correction, dossier:)
        end

        it 'does not create an new pending correction' do
          expect { subject }.not_to change { DossierCorrection.count }
        end

        it 'shows a flash alert' do
          subject

          expect(response.body).to include('')
        end
      end
    end

    context 'dossier en_construction' do
      it 'can create a pending correction' do
        subject
        expect(dossier.reload).to be_pending_correction
        expect(dossier.commentaires.last).to be_flagged_pending_correction
      end
    end

    context 'dossier is termine' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure) }

      it 'does not create a pending correction' do
        expect { subject }.not_to change { DossierCorrection.count }
        expect(response.body).to include('Impossible')
      end
    end
  end

  describe '#create_commentaire with pending_response flag' do
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
    let(:saved_commentaire) { dossier.commentaires.first }
    let(:body) { "Please respond" }

    before { sign_in(instructeur.user) }

    context 'when mark_as_pending_response is true' do
      subject do
        post :create_commentaire, params: {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          commentaire: { body: body },
          mark_as_pending_response: 'true',
        }
      end

      it 'creates a commentaire' do
        expect { subject }.to change { dossier.commentaires.count }.by(1)
      end

      it 'creates a pending response' do
        expect { subject }.to change { DossierPendingResponse.count }.by(1)
      end

      it 'creates an attente_reponse notification' do
        expect { subject }.to change { DossierNotification.where(notification_type: :attente_reponse).count }.by_at_least(1)
      end

      it 'links the pending response to the commentaire' do
        subject
        expect(DossierPendingResponse.last.commentaire).to eq(saved_commentaire)
      end

      it 'shows correct flash notice' do
        subject
        expect(flash.notice).to eq(I18n.t('instructeurs.dossiers.message_sent_with_pending_response'))
      end
    end

    context 'when mark_as_pending_response is false' do
      subject do
        post :create_commentaire, params: {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          commentaire: { body: body },
          mark_as_pending_response: 'false',
        }
      end

      it 'creates a commentaire' do
        expect { subject }.to change { dossier.commentaires.count }.by(1)
      end

      it 'does not create a pending response' do
        expect { subject }.not_to change { DossierPendingResponse.count }
      end

      it 'shows correct flash notice' do
        subject
        expect(flash.notice).to eq(I18n.t('instructeurs.dossiers.message_sent'))
      end
    end
  end

  describe '#messagerie' do
    before { expect(controller.current_instructeur).to receive(:mark_tab_as_seen).with(dossier, :messagerie) }
    subject { get :messagerie, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' } }
    it { expect(subject).to have_http_status(:ok) }

    context "when message notifications exists" do
      let!(:other_instructeur) { create(:instructeur) }
      let!(:notification_current_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :message) }
      let!(:notification_other_instructeur) { create(:dossier_notification, dossier:, instructeur: other_instructeur, notification_type: :message) }

      it "destroys notification only for the current_instructeur" do
        subject

        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier, notification_type: :message)
        ).to be_falsey

        expect(
          DossierNotification.exists?(instructeur: other_instructeur, dossier: dossier, notification_type: :message)
        ).to be_truthy
      end
    end
  end

  describe "#create_commentaire" do
    let(:saved_commentaire) { dossier.commentaires.first }
    let(:body) { "avant\napres" }
    let(:file) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }
    let(:scan_result) { true }
    let(:now) { DateTime.parse("12/02/2025 09:19") }
    let(:mark_as_pending_response) { nil }

    subject {
      post :create_commentaire, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        commentaire: {
          body: body,
          file: file,
        },
        mark_as_pending_response: mark_as_pending_response,
        statut: 'a-suivre',
      }
    }

    before do
      expect(controller.current_instructeur).to receive(:mark_tab_as_seen).with(dossier, :messagerie)
      allow(ClamavService).to receive(:safe_file?).and_return(scan_result)
      travel_to(now)
    end

    it "creates a commentaire" do
      expect { subject }.to change(Commentaire, :count).by(1)
      expect(instructeur.followed_dossiers).to include(dossier)

      expect(response).to redirect_to(messagerie_instructeur_dossier_path(dossier.procedure, dossier))
      expect(flash.notice).to be_present
      expect(dossier.reload.last_commentaire_updated_at).to eq(now)
    end

    context "when marking dossier as waiting for response" do
      let(:mark_as_pending_response) { 'true' }

      it "creates a commentaire and attente_reponse notification" do
        expect { subject }.to change(Commentaire, :count).by(1)
          .and change { DossierNotification.where(notification_type: :attente_reponse).count }.by_at_least(1)

        expect(flash.notice).to include("EN ATTENTE DE RÉPONSE")
      end
    end

    context "when the commentaire created with virus file" do
      let(:scan_result) { false }

      it "creates a commentaire (shows message that file have a virus)" do
        expect { subject }.to change(Commentaire, :count).by(1)
        expect(instructeur.followed_dossiers).to include(dossier)

        expect(response).to redirect_to(messagerie_instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.notice).to be_present
      end
    end

    context "when the dossier is deleted by user" do
      let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

      before do
        dossier.update!(hidden_by_user_at: 1.hour.ago)
        subject
      end

      it "does not create a commentaire" do
        expect { subject }.to change(Commentaire, :count).by(0)
        expect(flash.alert).to be_present
      end
    end

    context "when there are others instructeurs" do
      let(:another_instructeur) { create(:instructeur) }
      let(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, another_instructeur]) }
      let(:dossier) { create(:dossier, :en_construction, groupe_instructeur:, procedure:) }

      context "when others instructeurs are followers" do
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur: another_instructeur, procedure:, display_message_notifications: 'none') }

        before do
          another_instructeur.followed_dossiers << dossier
        end

        it "creates message notification only for instructeurs who have a 'followed' or 'all' preference" do
          subject

          expect(DossierNotification.count).to eq(0)
        end
      end

      context "when others instructeurs are not followers" do
        let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur: another_instructeur, procedure:, display_message_notifications: 'all') }

        it "creates message notification only for instructeurs who have an 'all' preference" do
          subject
          expect(DossierNotification.count).to eq(1)

          notification = DossierNotification.last
          expect(notification.dossier_id).to eq(dossier.id)
          expect(notification.instructeur_id).to eq(another_instructeur.id)
          expect(notification.notification_type).to eq("message")
        end
      end
    end
  end

  describe "#create_avis" do
    let(:expert) { create(:expert) }
    let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: dossier.procedure) }
    let(:invite_linked_dossiers) { false }
    let(:saved_avis) { dossier.avis.first }
    let!(:old_avis_count) { Avis.count }

    subject do
      post :create_avis, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        avis: { emails: emails, introduction: 'intro', confidentiel: true, invite_linked_dossiers: invite_linked_dossiers, claimant: instructeur, experts_procedure: experts_procedure },
        statut: 'a-suivre',
      }
    end

    let(:emails) { ["email@a.com"] }

    context 'as an instructeur, i auto follow the dossier' do
      it 'works' do
        subject
        expect(instructeur.followed_dossiers).to match_array([dossier])
        expect(dossier.follows.first.avis_seen_at?).to eq(true)
      end
    end

    context 'email sending' do
      before do
        subject
      end

      it do
        expect(saved_avis.expert.email).to eq('email@a.com')
        expect(saved_avis.introduction).to eq('intro')
        expect(saved_avis.confidentiel).to eq(true)
        expect(saved_avis.dossier).to eq(dossier)
        expect(saved_avis.claimant).to eq(instructeur)
        expect(response).to redirect_to(avis_instructeur_dossier_path(dossier.procedure, dossier))
      end

      context "with an invalid email" do
        let(:emails) { ["emaila.com"] }

        before { subject }

        it do
          expect(response).to render_template :avis_new
          expect(flash.alert).to eq("emaila.com : Le champ « Email » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
          expect { subject }.not_to change(Avis, :count)
          expect(dossier.last_avis_updated_at).to eq(nil)
        end
      end

      context "with no email" do
        let(:emails) { [] }

        before { subject }

        it do
          expect(response).to render_template :avis_new
          expect(flash.alert).to eq("Le champ « Email » doit être rempli")
          expect { subject }.not_to change(Avis, :count)
          expect(dossier.last_avis_updated_at).to eq(nil)
        end
      end

      context 'with multiple emails' do
        context 'with 2 mails' do
          let(:emails) { ["toto.fr", "titi@titimail.com"] }

          before { subject }

          it do
            expect(response).to render_template :avis_new
            expect(flash.alert).to eq("toto.fr : Le champ « Email » est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com")
            expect(flash.notice).to eq("Une demande d’avis a été envoyée à titi@titimail.com")
            expect(Avis.count).to eq(old_avis_count + 1)
            expect(saved_avis.expert.email).to eq("titi@titimail.com")
          end
        end

        context 'with 5 mails' do
          let(:emails) { ["test@test.com", "test2@test.com", "test3@test.com", "test4@test.com", "test5@test.com"] }

          before { subject }

          it do
            expect(flash.notice).to eq("Une demande d’avis a été envoyée à 5 destinataires")
            expect(Avis.count).to eq(old_avis_count + 5)
          end
        end
      end

      context 'when the expert do not want to receive notification' do
        let(:emails) { ["email@a.com"] }
        let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: dossier.procedure, notify_on_new_avis: false) }

        before { subject }
      end

      context 'with linked dossiers' do
        let(:asked_confidentiel) { false }
        let(:previous_avis_confidentiel) { false }
        let(:types_de_champ_public) { [{ type: :dossier_link }] }
        let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
        before { subject }
        context 'when the expert doesn’t share linked dossiers' do
          let(:invite_linked_dossiers) { false }

          it 'sends a single avis for the main dossier, but doesn’t give access to the linked dossiers' do
            expect(flash.notice).to eq("Une demande d’avis a été envoyée à email@a.com")
            expect(Avis.count).to eq(old_avis_count + 1)
            expect(saved_avis.expert.email).to eq("email@a.com")
            expect(saved_avis.dossier).to eq(dossier)
          end
        end

        context 'when the expert also shares the linked dossiers' do
          let(:invite_linked_dossiers) { true }

          context 'and the expert can access the linked dossiers' do
            let(:saved_avis) { Avis.last(2).first }
            let(:linked_avis) { Avis.last }
            let(:linked_dossier) { Dossier.find_by(id: dossier.champs.first.value) }
            let(:invite_linked_dossiers) do
              instructeur.assign_to_procedure(linked_dossier.procedure)
              true
            end

            it 'sends one avis for the main dossier' do
              expect(flash.notice).to eq("Une demande d’avis a été envoyée à email@a.com")
              expect(saved_avis.expert.email).to eq("email@a.com")
              expect(saved_avis.dossier).to eq(dossier)
            end

            it 'sends another avis for the linked dossiers' do
              expect(Avis.count).to eq(old_avis_count + 2)
              expect(linked_avis.dossier).to eq(linked_dossier)
            end
          end

          context 'but the expert can’t access the linked dossier' do
            it 'sends a single avis for the main dossier, but doesn’t give access to the linked dossiers' do
              expect(flash.notice).to eq("Une demande d’avis a été envoyée à email@a.com")
              expect(Avis.count).to eq(old_avis_count + 1)
              expect(saved_avis.expert.email).to eq("email@a.com")
              expect(saved_avis.dossier).to eq(dossier)
            end
          end
        end
      end
    end

    context "when there are instructeurs followers" do
      let!(:instructeur_not_follower) { create(:instructeur) }
      let!(:groupe_instructeur) { create(:groupe_instructeur, instructeurs: [instructeur, instructeur_not_follower]) }

      before do
        dossier.assign_to_groupe_instructeur(groupe_instructeur, DossierAssignment.modes.fetch(:auto))
      end

      it "create attente_avis notification only for instructeur follower" do
        expect { subject }.to change(DossierNotification, :count).by(1)

        notification = DossierNotification.last
        expect(notification.dossier_id).to eq(dossier.id)
        expect(notification.instructeur_id).to eq(instructeur.id)
        expect(notification.notification_type).to eq("attente_avis")
      end
    end
  end

  describe "#show" do
    context "when the dossier is exported as PDF" do
      let(:instructeur) { create(:instructeur) }
      let(:expert) { create(:expert) }
      let(:procedure) { create(:procedure, :published, instructeurs: instructeurs) }
      let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure) }
      let(:dossier) do
        create(:dossier,
          :accepte,
          :with_populated_champs,
          :with_populated_annotations,
          :with_motivation,
          :with_entreprise,
          :with_commentaires, procedure: procedure)
      end
      let!(:avis) { create(:avis, dossier: dossier, claimant: instructeur, experts_procedure: experts_procedure) }

      subject do
        avis
        get :show, params: {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          statut: 'a-suivre',
          format: :pdf,
        }
      end

      before do
        expect(controller.current_instructeur).to receive(:mark_tab_as_seen).with(dossier, :demande)
        subject
      end

      it do
        expect(assigns(:acls)).to eq(PiecesJustificativesService.new(user_profile: instructeur, export_template: nil).acl_for_dossier_export(dossier.procedure))
        expect(assigns(:is_dossier_in_batch_operation)).to eq(false)
        expect(response).to render_template 'dossiers/show'
      end

      context 'empty champs commune' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :communes }], instructeurs:) }
        let(:dossier) { create(:dossier, :accepte, procedure:) }

        it { expect(response).to render_template 'dossiers/show' }
      end
    end

    context 'with dossier in batch_operation' do
      let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it 'assigns variable with true value' do
        get :show, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
        expect(assigns(:is_dossier_in_batch_operation)).to eq(true)
      end
    end

    context "when dossier_modifie notifications exist" do
      let!(:other_instructeur) { create(:instructeur) }
      let!(:notification_current_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :dossier_modifie) }
      let!(:notification_other_instructeur) { create(:dossier_notification, dossier:, instructeur: other_instructeur, notification_type: :dossier_modifie) }

      it "destroys notification only for the current_instructeur" do
        get :show, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'suivis' }

        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier, notification_type: :dossier_modifie)
        ).to be_falsey

        expect(
          DossierNotification.exists?(instructeur: other_instructeur, dossier: dossier, notification_type: :dossier_modifie)
        ).to be_truthy
      end
    end

    context "when procedure has pro_connect restriction" do
      before do
        procedure.update!(pro_connect_restriction: :instructeurs)
      end

      it "redirects to pro_connect_restricted page" do
        get :show, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
        expect(response).to redirect_to(pro_connect_path)
      end
    end
  end

  describe 'navigation accross next/prev dossiers' do
    let(:dossier_id) { dossier.id }
    let(:statut) { 'a-suivre' }
    let(:previous_dossier) { create(:dossier, :en_construction, procedure:) }
    let(:next_dossier) { create(:dossier, :en_construction, procedure:) }
    let(:cached_ids) { [previous_dossier, dossier, next_dossier].map(&:id) }
    before do
      cache = Cache::ProcedureDossierPagination.new(procedure_presentation: double(procedure:, instructeur:), statut:)
      cache.save_context(incoming_page: 1, ids: cached_ids)
    end

    context 'when nexting' do
      subject { get :next, params: { procedure_id: procedure.id, dossier_id: from_id, statut: } }

      context 'when their is a next id' do
        let(:from_id) { dossier.id }
        it { is_expected.to redirect_to(instructeur_dossier_path(procedure_id: procedure.id, dossier_id: next_dossier.id)) }
      end

      context 'when their is not next id (en of list)' do
        let(:from_id) { cached_ids.last }
        it 'redirect on fallback location being current dossier and flashes an error' do
          expect(subject).to redirect_to(instructeur_dossier_path(procedure_id: procedure.id, dossier_id: from_id))
          expect(flash.alert).to eq("Une erreur est survenue")
        end
      end

      context 'when id does not exists' do
        let(:from_id) { 'kthxbye' }
        it 'redirect on fallback location being current dossier and flashes an error' do
          expect(subject).to redirect_to(instructeur_procedure_path(procedure_id: procedure.id))
          expect(flash.alert).to eq("Une erreur est survenue")
        end
      end
    end

    context 'when previousing' do
      subject { get :previous, params: { procedure_id: procedure.id, dossier_id: from_id, statut: } }

      context 'when their is a previous id' do
        let(:from_id) { dossier.id }
        it { is_expected.to redirect_to(instructeur_dossier_path(procedure_id: procedure.id, dossier_id: previous_dossier.id)) }
      end

      context 'when their is not previous id (before list)' do
        let(:from_id) { cached_ids.first }
        it 'redirect on fallback location being current dossier and flashes an error' do
          expect(subject).to redirect_to(instructeur_dossier_path(procedure_id: procedure.id, dossier_id: from_id))
          expect(flash.alert).to eq("Une erreur est survenue")
        end
      end

      context 'when id does not exists' do
        let(:from_id) { 'kthxbye' }
        it 'redirect on fallback location being current dossier and flashes an error' do
          expect(subject).to redirect_to(instructeur_procedure_path(procedure_id: procedure.id))
          expect(flash.alert).to eq("Une erreur est survenue")
        end
      end
    end
  end

  describe "#update_annotations" do
    let(:procedure) do
      create(:procedure, :published, types_de_champ_public:, types_de_champ_private:, instructeurs: instructeurs)
    end
    let(:types_de_champ_private) do
      [
        { type: :multiple_drop_down_list },
        { type: :linked_drop_down_list },
        { type: :datetime },
        { type: :repetition, children: [{}] },
        { type: :drop_down_list, options: [:a, :b, :other] },
      ]
    end
    let(:types_de_champ_public) { [] }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_annotations, procedure: procedure) }
    let(:another_instructeur) { create(:instructeur) }
    let(:now) { Time.zone.parse('01/01/2100') }

    let(:champ_repetition) { dossier.project_champs_private.fourth }
    let(:champ_text) { champ_repetition.rows.first.first }
    let(:champ_multiple_drop_down_list) { dossier.project_champs_private.first }
    let(:champ_linked_drop_down_list) { dossier.project_champs_private.second }
    let(:champ_datetime) { dossier.project_champs_private.third }
    let(:champ_drop_down_list) { dossier.project_champs_private.fifth }

    context 'when no invalid champs_public' do
      context "with new values for champs_private" do
        before do
          expect(controller.current_instructeur).to receive(:mark_tab_as_seen).with(dossier, :annotations_privees)
          another_instructeur.follow(dossier)
          travel_to(now)
          patch :update_annotations, params: params, format: :turbo_stream
          dossier.reload
          champ_multiple_drop_down_list.reload
          champ_linked_drop_down_list.reload
          champ_datetime.reload
          champ_drop_down_list.reload
          champ_text.reload
        end

        let(:champs_private_attributes) do
          {
            champ_multiple_drop_down_list.public_id => {
              value: ['', 'val1', 'val2'],
            },
          }
        end
        let(:params) do
          {
            procedure_id: procedure.id,
            dossier_id: dossier.id,
            dossier: { champs_private_attributes: },
          }
        end

        it {
          expect(champ_multiple_drop_down_list.value).to eq('["val1","val2"]')
          expect(dossier.last_champ_private_updated_at).to eq(now)
          expect(response).to have_http_status(200)
          assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob)
        }

        context 'datetime' do
          let(:champs_private_attributes) do
            {
              champ_datetime.public_id => {
                value: '2019-12-21T13:17',
              },
            }
          end

          it {
            expect(champ_datetime.value).to eq(Time.zone.parse('2019-12-21T13:17:00').iso8601)
            expect(dossier.last_champ_private_updated_at).to eq(now)
            expect(response).to have_http_status(200)
            assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob)
          }
        end

        context 'linked_drop_down' do
          let(:champs_private_attributes) do
            {
              champ_linked_drop_down_list.public_id => {
                primary_value: 'primary',
                secondary_value: 'secondary',
              },
            }
          end

          it {
            expect(champ_linked_drop_down_list.primary_value).to eq('primary')
            expect(champ_linked_drop_down_list.secondary_value).to eq('secondary')
            expect(dossier.last_champ_private_updated_at).to eq(now)
            expect(response).to have_http_status(200)
            assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob)
          }
        end

        context 'repetition' do
          let(:champs_private_attributes) do
            {
              champ_repetition.rows.first.first.public_id => {
                value: 'text',
              },
            }
          end

          it {
            expect(champ_text.value).to eq('text')
            expect(dossier.last_champ_private_updated_at).to eq(now)
            expect(response).to have_http_status(200)
            assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob)
          }

          context 'when one child is referentiel' do
            let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response) }
            let(:types_de_champ_private) do
              [
                { type: :multiple_drop_down_list },
                { type: :linked_drop_down_list },
                { type: :datetime },
                {
                  type: :repetition,
                  children: [
                    {
                      type: :referentiel,
                      referentiel_id: referentiel.id,
                    },
                  ],
                },
                { type: :drop_down_list, options: [:a, :b, :other] },
              ]
            end
            let(:champs_private_attributes) do
              {
                champ_repetition.rows.first.first.public_id => {
                  external_id: 'text',
                },
              }
            end

            it {
              expect(champ_text.external_id).to eq('text')
              expect(response).to have_http_status(200)
              expect(dossier.last_champ_private_updated_at).to eq(now)
              assert_enqueued_jobs(1, only: ChampFetchExternalDataJob)
            }
          end
        end

        context 'drop_down_list' do
          let(:champs_private_attributes) do
            {
              champ_drop_down_list.public_id => {
                value: '__other__',
                value_other: 'other value',
              },
            }
          end

          it {
            expect(champ_drop_down_list.value).to eq('other value')
            expect(dossier.last_champ_private_updated_at).to eq(now)
            expect(response).to have_http_status(200)
            assert_enqueued_jobs(1, only: DossierIndexSearchTermsJob)
          }
        end
      end

      context "without new values for champs_private" do
        let(:params) do
          {
            procedure_id: procedure.id,
            dossier_id: dossier.id,
            dossier: {
              champs_private_attributes: {},
              champs_public_attributes: {
                '0': {
                  id: champ_multiple_drop_down_list.id,
                  value: ['', 'val1', 'val2'],
                },
              },
            },
          }
        end

        it {
          expect(dossier.reload.last_champ_private_updated_at).to eq(nil)
          expect(response).to have_http_status(200)
        }
      end
    end

    after do
    end

    context "without new values for champs_private" do
      let(:params) do
        {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          dossier: {
            champs_private_attributes: {},
            champs_public_attributes: {
              champ_multiple_drop_down_list.public_id => {
                value: ['', 'val1', 'val2'],
              },
            },
          },
        }
      end

      it {
        expect(dossier.reload.last_champ_private_updated_at).to eq(nil)
        expect(response).to have_http_status(200)
      }
    end

    context "with invalid champs_public (DecimalNumberChamp)" do
      let(:types_de_champ_public) do
        [
          { type: :decimal_number },
        ]
      end

      let(:champ_decimal_number) { dossier.project_champs_public.first }

      let(:params) do
        {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          dossier: {
            champs_private_attributes: {
              champ_datetime.public_id => {
                value: '2024-03-30T07:03',
              },
            },
          },
        }
      end

      it 'update champs_private' do
        too_long_float = '3.1415'
        champ_decimal_number.update_column(:value, too_long_float)
        patch :update_annotations, params: params, format: :turbo_stream
        champ_datetime.reload
        expect(champ_datetime.value).to eq(Time.zone.parse('2024-03-30T07:03:00').iso8601)
      end
    end

    context "when there are others instructeurs" do
      let(:instructeurs) { [instructeur, another_instructeur] }
      let!(:other_instructeur_procedure) { create(:instructeurs_procedure, instructeur: another_instructeur, procedure:, display_annotation_instructeur_notifications: 'all') }
      let(:params) do
        {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          dossier: {
            champs_private_attributes: {
              champ_datetime.public_id => {
                value: '2024-03-30T07:03',
              },
            },
          },
        }
      end

      before do
        instructeur.followed_dossiers << dossier
        patch :update_annotations, params: params, format: :turbo_stream
      end

      it "create annotation_instructeur notification only for others instructeurs whish to be notified" do
        expect(DossierNotification.count).to eq(1)

        notification = DossierNotification.first
        expect(notification.dossier_id).to eq(dossier.id)
        expect(notification.instructeur_id).to eq(another_instructeur.id)
        expect(notification.notification_type).to eq("annotation_instructeur")
      end
    end
  end

  describe "#annotations_privees" do
    context "when annotation_instructeur notifications exist" do
      let!(:other_instructeur) { create(:instructeur) }
      let!(:notification_current_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :annotation_instructeur) }
      let!(:notification_other_instructeur) { create(:dossier_notification, dossier:, instructeur: other_instructeur, notification_type: :annotation_instructeur) }

      it "destroys notification only for the current_instructeur" do
        get :annotations_privees, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'suivis' }

        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier, notification_type: :annotation_instructeur)
        ).to be_falsey

        expect(
          DossierNotification.exists?(instructeur: other_instructeur, dossier: dossier, notification_type: :annotation_instructeur)
        ).to be_truthy
      end
    end
  end

  describe "#avis" do
    context "when avis_externe notifications exist" do
      let!(:other_instructeur) { create(:instructeur) }
      let!(:notification_current_instructeur) { create(:dossier_notification, dossier:, instructeur:, notification_type: :avis_externe) }
      let!(:notification_other_instructeur) { create(:dossier_notification, dossier:, instructeur: other_instructeur, notification_type: :avis_externe) }

      it "destroys notification only for the current_instructeur" do
        get :avis, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'suivis' }

        expect(
          DossierNotification.exists?(instructeur:, dossier: dossier, notification_type: :avis_externe)
        ).to be_falsey

        expect(
          DossierNotification.exists?(instructeur: other_instructeur, dossier: dossier, notification_type: :avis_externe)
        ).to be_truthy
      end
    end
  end

  describe "#telecharger_pjs" do
    subject do
      get :telecharger_pjs, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
      }
    end

    before do
      allow_any_instance_of(PiecesJustificativesService).to receive(:generate_dossiers_export).with([dossier]).and_call_original
    end

    it 'includes an attachment' do
      expect(subject.headers['Content-Disposition']).to start_with('attachment; ')
    end

    it 'the attachment.zip is extractable' do
      Tempfile.create(['test', '.zip']) do |f|
        f.binmode
        f.write(subject.body)
        f.close

        file_names = []
        Zip::File.open(f.path) do |zip|
          file_names = zip.entries.map(&:name)
        end

        expect(file_names.size).to eq(1)
        expect(file_names.first).to start_with("dossier-#{dossier.id}/export-")
      end
    end
  end

  describe "#destroy" do
    let(:batch_operation) {}
    subject do
      batch_operation
      delete :destroy, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        statut: 'a-suivre',
      }
    end

    before do
      dossier.passer_en_instruction(instructeur: instructeur)
    end

    context 'just before delete the dossier, the operation must be equal to 2' do
      before do
        dossier.accepter!(instructeur: instructeur, motivation: 'le dossier est correct')
      end

      it 'has 2 operations logs before deletion' do
        expect(DossierOperationLog.where(dossier_id: dossier.id).count).to eq(2)
      end
    end

    context 'when the instructeur want to delete a dossier with a decision and already hidden by user' do
      before do
        dossier.accepter!(instructeur: instructeur, motivation: "le dossier est correct")
        dossier.update!(hidden_by_user_at: Time.zone.now.beginning_of_day.utc)
        subject
      end

      it 'deletes previous logs and add a suppression log' do
        expect(DossierOperationLog.where(dossier_id: dossier.id).count).to eq(3)
        expect(DossierOperationLog.where(dossier_id: dossier.id).last.operation).to eq('supprimer')
      end

      it 'does not add a record into deleted_dossiers table' do
        expect(DeletedDossier.where(dossier_id: dossier.id).count).to eq(0)
      end

      it 'is not visible by administration' do
        expect(dossier.reload.visible_by_administration?).to be_falsy
      end
    end

    context 'when the instructeur want to delete a dossier with a decision and not hidden by user' do
      before do
        dossier.accepter!(instructeur: instructeur, motivation: "le dossier est correct")
        subject
      end

      it 'does not deletes previous logs and adds a suppression log' do
        expect(DossierOperationLog.where(dossier_id: dossier.id).count).to eq(3)
        expect(DossierOperationLog.where(dossier_id: dossier.id).last.operation).to eq('supprimer')
      end

      it 'add a record into deleted_dossiers table' do
        expect(DeletedDossier.where(dossier_id: dossier.id).count).to eq(0)
      end

      it 'fill hidden by reason' do
        expect(dossier.reload.hidden_by_reason).not_to eq(nil)
        expect(dossier.reload.hidden_by_reason).to eq("instructeur_request")
      end
    end

    context 'when the instructeur want to delete a dossier without a decision' do
      before do
        subject
      end

      it 'does not delete the dossier' do
        expect { dossier.reload }.not_to raise_error # A deleted dossier would raise an ActiveRecord::RecordNotFound
      end

      it 'does not add a record into deleted_dossiers table' do
        expect(DeletedDossier.where(dossier_id: dossier.id).count).to eq(0)
      end
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect { subject }.not_to change { dossier.reload.hidden_by_administration_at }
        is_expected.to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
      end
      it 'flashes message' do
       subject
       expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
     end
    end
  end

  describe '#extend_conservation' do
    subject { post :extend_conservation, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' } }
    context 'when user logged in' do
      it 'works' do
        expect(subject).to redirect_to(instructeur_dossier_path(procedure, dossier))
      end

      it 'extends conservation_extension by 1 month' do
        subject
        expect(dossier.reload.conservation_extension).to eq(1.month)
      end

      it 'flashed notice success' do
        subject
        expect(flash[:notice]).to eq(I18n.t('views.instructeurs.dossiers.archived_dossier'))
      end
    end

    context 'with dossier in batch_operation' do
       let!(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
       it do
         expect { subject }.not_to change { dossier.reload.conservation_extension }
         is_expected.to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
       end
       it 'flashes message' do
         subject
         expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
       end
     end
  end

  describe '#restore' do
    let(:instructeur) { create(:instructeur) }
    let!(:gi_p1_1) { GroupeInstructeur.create(label: '1', procedure: procedure) }
    let!(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }
    let!(:dossier) { create(:dossier, :accepte, :with_individual, procedure: procedure, groupe_instructeur: procedure.groupe_instructeurs.first, hidden_by_administration_at: 1.hour.ago) }
    let(:batch_operation) {}
    before do
      sign_in(instructeur.user)
      batch_operation
      instructeur.groupe_instructeurs << gi_p1_1
      patch :restore,
      params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        statut: 'a-suivre',
      }
    end

    it "puts hidden_by_administration_at to nil" do
      expect(dossier.reload.hidden_by_administration_at).to eq(nil)
    end

    context 'with dossier in batch_operation' do
      let(:batch_operation) { create(:batch_operation, operation: :archiver, dossiers: [dossier], instructeur: instructeur) }
      it do
        expect(dossier.hidden_by_administration_at).not_to eq(nil)
        expect(response).to redirect_to(instructeur_dossier_path(dossier.procedure, dossier))
        expect(flash.alert).to eq("Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse.")
      end
    end
  end

  describe '#extend_conservation and restore' do
    subject { post :extend_conservation_and_restore, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' } }

    before do
      dossier.update(hidden_by_expired_at: 1.hour.ago, hidden_by_reason: 'expired')
    end

    context 'when dossier has expired but was not hidden by anyone' do
      it 'works' do
        expect(subject).to redirect_to(instructeur_dossier_path(procedure, dossier))
      end

      it 'extends conservation_extension by 1 month and let dossier not hidden' do
        subject
        expect(dossier.reload.conservation_extension).to eq(1.month)
        expect(dossier.reload.hidden_by_reason).to eq(nil)
        expect(dossier.reload.hidden_by_expired_at).to eq(nil)
        expect(dossier.reload.hidden_by_administration_at).to eq(nil)
        expect(dossier.reload.hidden_by_user_at).to eq(nil)
      end

      it 'flashed notice success' do
        subject
        expect(flash[:notice]).to eq(I18n.t('views.instructeurs.dossiers.archived_dossier'))
      end
    end

    context 'when dossier has expired and was hidden by instructeur' do
      let!(:dossier) { create(:dossier, :hidden_by_administration, :accepte, :with_individual, procedure: procedure) }

      it 'extends conservation_extension by 1 month and restore dossier for instructeur' do
        subject
        expect(dossier.reload.conservation_extension).to eq(1.month)
        expect(dossier.reload.hidden_by_reason).to eq(nil)
        expect(dossier.reload.hidden_by_expired_at).to eq(nil)
        expect(dossier.reload.hidden_by_administration_at).to eq(nil)
        expect(dossier.reload.hidden_by_user_at).to eq(nil)
      end
    end

    context 'when dossier has expired and was hidden by user' do
      let!(:dossier) { create(:dossier, :hidden_by_user, :accepte, :with_individual, procedure: procedure) }
      it 'extends conservation_extension by 1 month and let dossier hidden for user' do
        subject
        expect(dossier.reload.conservation_extension).to eq(1.month)
        expect(dossier.reload.hidden_by_reason).to eq("user_request")
        expect(dossier.reload.hidden_by_expired_at).to eq(nil)
        expect(dossier.reload.hidden_by_administration_at).to eq(nil)
        expect(dossier.reload.hidden_by_user_at).not_to eq(nil)
      end
    end

    context 'when dossier has expired and was hidden by user and instructeur' do
      let!(:dossier) { create(:dossier, :hidden_by_user, :hidden_by_administration, :accepte, :with_individual, procedure: procedure) }
      it 'extends conservation_extension by 1 month and let dossier hidden for user' do
        subject
        expect(dossier.reload.conservation_extension).to eq(1.month)
        expect(dossier.reload.hidden_by_reason).to eq("user_request")
        expect(dossier.reload.hidden_by_expired_at).to eq(nil)
        expect(dossier.reload.hidden_by_administration_at).to eq(nil)
        expect(dossier.reload.hidden_by_user_at).not_to eq(nil)
      end
    end
  end

  describe '#reaffectation' do
    let!(:gi_2) { GroupeInstructeur.create(label: 'deuxième groupe', procedure: procedure) }
    let!(:gi_3) { GroupeInstructeur.create(label: 'troisième groupe', procedure: procedure) }
    let!(:dossier) { create(:dossier, :en_construction, procedure: procedure, groupe_instructeur: procedure.groupe_instructeurs.reorder(:id).first) }

    before do
      post :reaffectation,
         params: {
           procedure_id: procedure.id,
           dossier_id: dossier.id,
           statut: 'a-suivre',
         }
    end

    it do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ce dossier est affecté au groupe « défaut ». Vous pouvez le réaffecter à lʼun des 2 autres groupes instructeurs")
    end
  end

  describe '#reaffecter' do
    let!(:gi_1) { procedure.groupe_instructeurs.first }
    let!(:gi_2) { GroupeInstructeur.create(label: 'deuxième groupe', procedure: procedure) }
    let!(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: procedure, groupe_instructeur: gi_1) }
    let!(:new_instructeur) { create(:instructeur) }

    before do
      gi_1.instructeurs << new_instructeur
      new_instructeur.followed_dossiers << dossier

      post :reaffecter,
        params: {
          procedure_id: procedure.id,
          dossier_id: dossier.id,
          groupe_instructeur_id: gi_2.id,
          statut: 'a-suivre',
        }
    end

    it do
      expect(dossier.reload.groupe_instructeur.id).to eq(gi_2.id)
      expect(dossier.forced_groupe_instructeur).to be_truthy
      expect(dossier.followers_instructeurs).to eq []
      expect(dossier.dossier_assignment.previous_groupe_instructeur_id).to eq(gi_1.id)
      expect(dossier.dossier_assignment.previous_groupe_instructeur_label).to eq(gi_1.label)
      expect(dossier.dossier_assignment.groupe_instructeur_id).to eq(gi_2.id)
      expect(dossier.dossier_assignment.groupe_instructeur_label).to eq(gi_2.label)
      expect(dossier.dossier_assignment.mode).to eq('manual')
      expect(dossier.dossier_assignment.assigned_by).to eq(instructeur.email)
      expect(response).to redirect_to(instructeur_procedure_path(procedure))
      expect(flash.notice).to eq("Le dossier n° #{dossier.id} a été réaffecté au groupe d’instructeurs « deuxième groupe ».")
    end
  end

  describe '#personnes_impliquees' do
    let(:routed_procedure) { create(:procedure, :routee, :published, :for_individual) }
    let(:gi_1) { routed_procedure.groupe_instructeurs.reorder(:id).first }
    let(:gi_2) { routed_procedure.groupe_instructeurs.reorder(:id).last }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure: routed_procedure, groupe_instructeur: gi_1) }
    let(:new_instructeur) { create(:instructeur) }

    before do
      gi_1.instructeurs << new_instructeur
      gi_2.instructeurs << instructeur
      new_instructeur.followed_dossiers << dossier
      dossier.assign_to_groupe_instructeur(gi_2, DossierAssignment.modes.fetch(:manual), new_instructeur)

      get :personnes_impliquees,
        params: {
          procedure_id: routed_procedure.id,
          dossier_id: dossier.id,
          statut: 'a-suivre',
        }
    end

    it do
      expect(response.body).to include('a réaffecté ce dossier du groupe « défaut » au groupe « deuxième groupe »')
    end
  end

  describe '#print' do
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    subject do
      get :print, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
      }
    end

    it { expect(subject).to have_http_status(:ok) }
  end

  describe '#pieces_jointes' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }], instructeurs:) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let(:logo_path) { 'spec/fixtures/files/logo_test_procedure.png' }
    let(:rib_path) { 'spec/fixtures/files/RIB.pdf' }
    let(:commentaire) { create(:commentaire, dossier: dossier) }
    let(:expert) { create(:expert) }
    let(:experts_procedure) { create(:experts_procedure, expert: expert, procedure: procedure) }
    let(:avis) { create(:avis, :with_answer, :with_piece_justificative, dossier: dossier, claimant: expert, experts_procedure: experts_procedure) }

    before do
      dossier.champs.first.piece_justificative_file.attach(
        io: File.open(logo_path),
        filename: "logo_test_procedure.png",
        content_type: "image/png",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )

      commentaire.piece_jointe.attach(
        io: File.open(rib_path),
        filename: "RIB.pdf",
        content_type: "application/pdf",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )

      avis.piece_justificative_file.attach(
        io: File.open(rib_path),
        filename: "RIB.pdf",
        content_type: "application/pdf",
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )

      get :pieces_jointes, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
        statut: 'a-suivre',
      }
    end

    it 'returns pieces jointes from champs, messagerie and avis' do
      expect(response.body).to have_text("Télécharger le fichier \ntoto.txt")
      expect(response.body).to have_text("Télécharger le fichier \nlogo_test_procedu...")
      expect(response.body).to have_text("Télécharger le fichier \nRIB.pdf")
      expect(response.body).to include('Visualiser')
      expect(response.body).to include('Pièce jointe au message')
      expect(response.body).to include('Pièce jointe à l’avis')
      expect(assigns(:gallery_attachments).count).to eq 4
      expect(assigns(:gallery_attachments)).to all(be_a(ActiveStorage::Attachment))
      expect([Champs::PieceJustificativeChamp, Champs::TitreIdentiteChamp, Commentaire, Avis]).to include(*assigns(:gallery_attachments).map { _1.record.class })
    end
  end

  describe 'dossier_labels' do
    let(:procedure) { create(:procedure, :with_labels, instructeurs: [instructeur]) }
    let!(:dossier) { create(:dossier, :en_construction, procedure:) }
    context 'it create dossier labels' do
      subject { post :dossier_labels, params: { procedure_id: procedure.id, dossier_id: dossier.id, label_id: [Label.first.id], statut: 'a-suivre' }, format: :turbo_stream }
      it 'works' do
        subject
        dossier.reload

        expect(dossier.dossier_labels.count).to eq(1)
        expect(subject.body).to include('fr-tag--purple-glycine')
        expect(subject.body).not_to include('Ajouter un label')
      end
    end

    context 'it remove dossier labels' do
      before do
        DossierLabel.create(dossier_id: dossier.id, label_id: dossier.procedure.labels.first.id)
      end

      subject { post :dossier_labels, params: { procedure_id: procedure.id, dossier_id: dossier.id, label_id: [], statut: 'a-suivre' }, format: :turbo_stream }

      it 'works' do
        expect(dossier.dossier_labels.count).to eq(1)

        subject
        dossier.reload

        expect(dossier.dossier_labels.count).to eq(0)
        expect(subject.body).to include('Ajouter un label')
      end
    end
  end

  describe '#rendez_vous' do
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    render_views

    subject do
      get :rendez_vous, params: {
        procedure_id: procedure.id,
        dossier_id: dossier.id,
      }
    end

    context 'when current_instructeur has no rdv_connection' do
      before do
        allow(instructeur).to receive(:rdv_connection).and_return(nil)
      end

      it 'should not crash' do
        expect { subject }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
