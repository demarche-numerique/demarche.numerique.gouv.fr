# frozen_string_literal: true

RSpec.describe DossierStateConcern do
  include Logic

  let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:, declarative_with_state:, auto_archive_on:) }
  let(:types_de_champ_public) do
    [
      { type: :text, stable_id: 90 },
      { type: :text, stable_id: 91 },
      { type: :piece_justificative, stable_id: 92, condition: ds_eq(constant(true), constant(false)) },
      { type: :titre_identite, stable_id: 93, condition: ds_eq(constant(true), constant(false)) },
      { type: :repetition, stable_id: 94, children: [{ type: :text, stable_id: 941 }, { type: :text, stable_id: 942 }] },
      { type: :repetition, stable_id: 95, children: [{ type: :text, stable_id: 951 }] },
      { type: :repetition, stable_id: 96, children: [{ type: :text, stable_id: 961 }], condition: ds_eq(constant(true), constant(false)) },
      { type: :text, stable_id: 97, condition: ds_eq(constant(true), constant(false)) },
      { type: :titre_identite, stable_id: 98 },
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
      champ_repetition = dossier.project_champs_public.find { _1.stable_id == 94 }
      row_id = champ_repetition.row_ids.first
      dossier.champs.filter(&:row?).find { _1.row_id == row_id }.touch(:discarded_at)
    end
  end

  describe 'submit brouillon' do
    it do
      expect(dossier.champs.size).to eq(20)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champs.filter { _1.row? && _1.discarded? }.size).to eq(1)
      expect(dossier.champs.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(4)
      expect(dossier.champs.filter { _1.stable_id.in?([90, 92, 93, 97, 961, 951]) }.size).to eq(8)

      champ_text = dossier.project_champs_public.find { _1.stable_id == 90 }
      champ_text.update(value: '')

      dossier.passer_en_construction!
      dossier.reload

      expect(dossier.champs.size).to eq(7)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champs.filter { _1.row? && _1.discarded? }.size).to eq(0)
      expect(dossier.champs.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(0)
      expect(dossier.champs.filter { _1.stable_id.in?([90, 92, 93, 97, 961, 951]) && !(_1.blank? || !_1.visible?) }.size).to eq(0)
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
      expect(dossier.champs.size).to eq(20)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champs.filter { _1.row? && _1.discarded? }.size).to eq(1)
      expect(dossier.champs.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(4)
      expect(dossier.champs.filter { _1.stable_id.in?([92, 93, 97, 961, 951]) }.size).to eq(7)

      dossier.usager_submit_en_construction!
      dossier.reload

      expect(dossier.champs.size).to eq(7)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champs.filter { _1.row? && _1.discarded? }.size).to eq(0)
      expect(dossier.champs.filter { _1.row? && _1.stable_id.in?([95, 96]) }.size).to eq(0)
      expect(dossier.champs.filter { _1.stable_id.in?([92, 93, 97, 961, 951]) && !(_1.blank? || !_1.visible?) }.size).to eq(0)
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

  describe 'accepter' do
    let(:dossier_state) { :en_instruction }

    it do
      expect(dossier.champs.size).to eq(20)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.accepter!(motivation: 'test')
      dossier.reload

      expect(dossier.champs.size).to eq(17)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
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
      expect(dossier.champs.size).to eq(20)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.refuser!(motivation: 'test')
      dossier.reload

      expect(dossier.champs.size).to eq(17)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
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
      expect(dossier.champs.size).to eq(20)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

      dossier.classer_sans_suite!(motivation: 'test')
      dossier.reload

      expect(dossier.champs.size).to eq(17)
      expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
      expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
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
        expect(dossier.champs.size).to eq(20)
        expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(2)
        expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) }.size).to eq(2)

        dossier.accepter_automatiquement!
        dossier.reload

        expect(dossier.champs.size).to eq(17)
        expect(dossier.champs.filter { _1.row? && _1.stable_id == 94 }.size).to eq(1)
        expect(dossier.champs.filter { _1.stable_id.in?([93, 98]) && _1.blank? }.size).to eq(2)
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

  describe 'auto purge piece justificative after decision' do
    let(:file) { fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png') }

    before { allow(ClamavService).to receive(:safe_file?).and_return(true) }

    context 'when nature is TITRE_IDENTITE' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, nature: 'TITRE_IDENTITE' }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champs.first }

      it 'destroys champ on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end
    end

    context 'when pj_auto_purge is enabled' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, pj_auto_purge: '1' }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champs.first }

      it 'destroys champ on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be false
      end
    end

    context 'when standard piece justificative' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, :en_instruction, :followed, procedure:) }
      let(:instructeur) { dossier.followers_instructeurs.first }
      let(:champ) { dossier.champs.first }

      it 'keeps attachments on accepter' do
        champ.piece_justificative_file.attach(file)
        dossier.accepter!(instructeur: instructeur, motivation: 'ok')
        expect(champ.reload.piece_justificative_file.attached?).to be true
      end
    end
  end

  describe '#clear_france_connect_champs_piece_justificatives (after user submits a dossier or modifications)' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :quotient_familial }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

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
end
