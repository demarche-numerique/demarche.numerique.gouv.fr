# frozen_string_literal: true

RSpec.describe Dossiers::MessageComponent, type: :component do
  let(:component) do
    described_class.new(
      commentaire: commentaire,
      connected_user: connected_user,
      messagerie_seen_at: seen_at,
      groupe_gestionnaire: groupe_gestionnaire
    )
  end
  before do
    allow(component).to receive(:params).and_return({ statut: 'a-suivre' })
  end

  let(:seen_at) { commentaire.created_at + 1.hour }

  describe 'for dossier' do
    let(:connected_user) { dossier.user }
    let(:dossier) { create(:dossier, :en_construction) }
    let(:commentaire) { create(:commentaire, dossier: dossier) }
    let(:groupe_gestionnaire) { nil }

    subject { render_inline(component).to_html }
    describe 'read receipt (usager => instructeur)' do
      let(:connected_user) { dossier.user }
      let(:dossier) { create(:dossier, :en_construction) }
      let(:commentaire) { create(:commentaire, dossier: dossier, email: connected_user.email, body: 'msg') }

      context 'when recipient has seen the message' do
        before { commentaire.update!(seen_by_recipient_at: Time.current) }
        it { is_expected.to include('Lu') }
      end

      context 'when recipient has not seen the message' do
        before { commentaire.update!(seen_by_recipient_at: nil) }
        it { is_expected.to include('Non lu') }
      end
    end

    describe 'read receipt (instructeur => usager)' do
      let(:instructeur) { create(:instructeur) }
      let(:dossier) { create(:dossier, :en_construction) }
      let(:connected_user) { instructeur }
      let(:commentaire) { create(:commentaire, dossier: dossier, instructeur: instructeur, body: 'msg') }

      context 'when recipient has seen the message' do
        before { commentaire.update!(seen_by_recipient_at: Time.current) }

        it do
          is_expected.to include('Lu')
          is_expected.not_to include('Non lu')
        end
      end

      context 'when recipient has not seen the message' do
        before { commentaire.update!(seen_by_recipient_at: nil) }
        it { is_expected.to include('Non lu') }
      end
    end

    context 'escape <img> tag' do
      before { commentaire.update(body: '<img src="demarches-simplifiees.fr" />Hello') }
      it { is_expected.not_to have_selector('img[src="demarches-simplifiees.fr"]') }
    end

    context 'attachments visibility' do
      let(:rib_path) { 'spec/fixtures/files/RIB.pdf' }

      before do
        commentaire.piece_jointe.attach(
          io: File.open(rib_path),
          filename: 'RIB.pdf',
          content_type: 'application/pdf',
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end

      context 'when commentaire is not discarded' do
        it 'displays the attachment' do
          is_expected.to include('RIB.pdf')
        end
      end

      context 'when commentaire is discarded' do
        before { commentaire.discard! }

        it 'does not display the attachment' do
          is_expected.not_to include('RIB.pdf')
        end
      end
    end

    context 'with a seen_at after commentaire created_at' do
      let(:seen_at) { commentaire.created_at + 1.hour  }

      it { is_expected.not_to have_css(".highlighted") }
    end

    context 'with an instructeur message' do
      let(:instructeur) { create(:instructeur) }
      let(:procedure) { create(:procedure, hide_instructeurs_email: true) }
      let(:commentaire) { create(:commentaire, instructeur: instructeur, body: 'Second message') }
      let(:dossier) { create(:dossier, :en_construction, commentaires: [commentaire], procedure: procedure) }

      context 'on a procedure with anonymous instructeurs' do
        context 'redacts the instructeur email' do
          it do
            is_expected.to have_text(commentaire.body)
            is_expected.to have_text("Instructeur n° #{instructeur.id}")
            is_expected.not_to have_text(instructeur.email)
          end
        end
      end

      context 'on a procedure where instructeurs names are not redacted' do
        let(:procedure) { create(:procedure, hide_instructeurs_email: false) }

        context 'redacts the instructeur email but keeps the name' do
          it do
            is_expected.to have_text(commentaire.body)
            is_expected.to have_text(instructeur.email.split('@').first)
            is_expected.not_to have_text("[Vous]")
            is_expected.not_to have_text(instructeur.email)
          end
        end
      end

      describe 'delete message button for instructeur' do
        let(:instructeur) { create(:instructeur) }
        let(:procedure) { create(:procedure) }
        let(:dossier) { create(:dossier, :en_construction, commentaires: [commentaire], procedure: procedure) }
        let(:connected_user) { instructeur }
        let(:form_url) { component.helpers.instructeur_commentaire_path(commentaire.dossier.procedure, commentaire.dossier, commentaire) }

        context 'on a procedure where commentaire had been written by connected instructeur' do
          let(:commentaire) { create(:commentaire, instructeur: instructeur, body: 'Second message') }

          it do
            is_expected.to have_selector("form[action=\"#{form_url}\"]")
            is_expected.to have_button(component.t('.delete_button'))
            is_expected.to have_selector(".fr-background-alt--blue-cumulus")
            is_expected.to have_text("[Vous]")
          end
        end

        context 'on a procedure where commentaire had been written by connected instructeur and discarded' do
          let(:commentaire) { create(:commentaire, instructeur: instructeur, body: 'Second message', discarded_at: 2.days.ago) }

          it do
            is_expected.not_to have_selector("form[action=\"#{form_url}\"]")
            is_expected.to have_selector(".rich-text", text: component.t('.deleted_body'))
          end
        end

        context 'on a procedure where commentaire had been written by connected an user' do
          let(:commentaire) { create(:commentaire, email: create(:user).email, body: 'Second message') }
          let(:email) { create(:commentaire, email:, body: 'Second message') }

          it do
            is_expected.not_to have_selector("form[action=\"#{form_url}\"]")
            is_expected.to have_selector(".fr-background-alt--brown-cafe-creme")
            is_expected.not_to have_text("[Vous]")
          end
        end

        context 'on a procedure where commentaire had been written by connected an expert' do
          let(:commentaire) { create(:commentaire, expert: create(:expert), body: 'Second message') }

          it do
            is_expected.not_to have_selector("form[action=\"#{form_url}\"]")
            is_expected.to have_selector(".fr-background-alt--blue-cumulus")
          end
        end

        context 'on a procedure where commentaire had been written another instructeur' do
          let(:commentaire) { create(:commentaire, instructeur: create(:instructeur), body: 'Second message') }

          it { is_expected.not_to have_selector("form[action=\"#{form_url}\"]") }
        end

        context 'when commentaire is a pending correction' do
          let(:commentaire) { create(:commentaire, instructeur:, body: 'Please fix this') }
          before { create(:dossier_correction, commentaire:, dossier:) }

          it 'displays the cancel correction button instead of delete' do
            is_expected.to have_button(component.t('.cancel_correction_button'))
            is_expected.not_to have_button(component.t('.delete_button'))
          end
        end

        context 'when commentaire is a cancelled correction' do
          let(:commentaire) { create(:commentaire, instructeur:, body: 'Please fix this') }
          before { create(:dossier_correction, commentaire:, dossier:, cancelled_at: Time.current, resolved_at: Time.current) }

          it 'displays the delete button' do
            is_expected.to have_button(component.t('.delete_button'))
            is_expected.not_to have_button(component.t('.cancel_correction_button'))
          end
        end
      end

      describe 'autolink simple urls' do
        let(:commentaire) { create(:commentaire, instructeur: instructeur, body: "rdv sur https://demarche.numerique.gouv.fr") }
        it { is_expected.to have_link("https://demarche.numerique.gouv.fr", href: "https://demarche.numerique.gouv.fr") }
      end
    end

    describe '#commentaire_from_guest?' do
      let!(:guest) { create(:invite, dossier: dossier) }

      subject { component.send(:commentaire_from_guest?) }

      context 'when the commentaire sender is not a guest' do
        let(:commentaire) { create(:commentaire, dossier: dossier, email: "michel@pref.fr") }
        it { is_expected.to be false }
      end

      context 'when the commentaire sender is a guest on this dossier' do
        let(:commentaire) { create(:commentaire, dossier: dossier, email: guest.email) }
        it { is_expected.to be true }
      end
    end

    describe '#commentaire_date' do
      let(:present_date) { Time.zone.local(2018, 9, 2, 10, 5, 0) }
      let(:creation_date) { present_date }
      let(:commentaire) do
        travel_to(creation_date) { create(:commentaire, email: "michel@pref.fr") }
      end

      subject do
        travel_to(present_date) { component.send(:commentaire_date) }
      end

      it 'formats as numeric date with year' do
        expect(subject).to eq 'Le 02/09/2018 10:05'
      end

      context 'when displaying a commentaire created on a previous year' do
        let(:creation_date) { present_date.prev_year }
        it 'formats as numeric date with previous year' do
          expect(subject).to eq 'Le 02/09/2017 10:05'
        end
      end

      context 'when formatting the first day of the month' do
        let(:present_date) { Time.zone.local(2018, 9, 1, 10, 5, 0) }
        it 'formats as numeric date for first day of month' do
          expect(subject).to eq 'Le 01/09/2018 10:05'
        end
      end
    end

    describe '#correction_badge' do
      context "when the correction is not resolved" do
        let!(:correction) { create(:dossier_correction, commentaire:, dossier:, resolved_at: nil) }

        it 'returns a badge à corriger' do
          expect(subject).to have_text('à corriger')
        end

        context 'connected as instructeur' do
          let(:connected_user) { create(:instructeur) }

          it 'returns a badge en attente' do
            expect(subject).to have_text('en attente')
          end
        end
      end

      context 'when the correction is resolved' do
        context "when the dossier has not been modified due to a change en_instruction" do
          let!(:correction) { create(:dossier_correction, commentaire:, dossier:, resolved_at: 1.minute.ago) }

          it 'returns a badge non modifié' do
            expect(subject).to have_text("non modifié")
          end
        end

        context "when the dossier has been modified" do
          let!(:correction) { create(:dossier_correction, commentaire:, dossier:, resolved_at: nil) }

          before { dossier.usager_submit_en_construction! }

          it 'returns a badge modifié' do
            correction.reload
            expect(subject).to have_text("modifié")
          end
        end

        context "when the correction has been cancelled by instructeur" do
          let!(:correction) { create(:dossier_correction, commentaire:, dossier:, cancelled_at: Time.current, resolved_at: Time.current) }

          it "returns a badge correction annulée" do
            expect(subject).to have_text("Demande de correction annulée")
          end
        end
      end
    end

    describe 'correction alert for usager' do
      let(:connected_user) { dossier.user }
      let(:dossier) { create(:dossier, :en_construction) }
      let(:commentaire) { create(:commentaire, dossier: dossier) }

      subject { render_inline(component) }

      context 'when there is a pending correction' do
        before do
          create(:dossier_correction, commentaire: commentaire, dossier: dossier, resolved_at: nil)
        end

        it 'displays the correction alert' do
          expect(subject).to have_css('.fr-alert')
          expect(subject).to have_css('.fr-alert--warning')
          expect(subject).to have_text(component.t('.alert_correction_title'))
          expect(subject).to have_text(component.t('.alert_correction_description'))
          expect(subject).to have_link(
            component.t('.alert_correction_cta'),
            href: component.helpers.modifier_dossier_path(dossier)
          )
        end
      end

      context 'when connected as instructeur' do
        let(:connected_user) { create(:instructeur) }

        before do
          create(:dossier_correction, commentaire: commentaire, dossier: dossier, resolved_at: nil)
        end

        it 'does not display the correction alert' do
          expect(subject).not_to have_css('.fr-alert')
        end
      end

      context 'when there is no correction' do
        it 'does not display the correction alert' do
          expect(subject).not_to have_css('.fr-alert')
        end
      end

      context 'when the correction is cancelled' do
        before do
          create(:dossier_correction, commentaire: commentaire, dossier: dossier, cancelled_at: Time.current)
        end

        it 'does not display the correction alert' do
          expect(subject).not_to have_css('.fr-alert')
        end
      end
    end
  end

  describe 'groupe_gestionnaire' do
    let(:commentaire) { create(:commentaire_groupe_gestionnaire, sender: administrateurs(:default_admin)) }
    let(:groupe_gestionnaire) { commentaire.groupe_gestionnaire }
    let(:connected_user) { commentaire.sender }
    subject { render_inline(component).to_html }

    context 'escape <img> tag' do
      before { commentaire.update(body: '<img src="demarches-simplifiees.fr" />Hello') }
      it { is_expected.not_to have_selector('img[src="demarches-simplifiees.fr"]') }
    end

    context 'with a seen_at after commentaire created_at' do
      let(:seen_at) { commentaire.created_at + 1.hour  }

      it { is_expected.not_to have_css(".highlighted") }
    end

    context 'with an gestionnaire message' do
      let(:gestionnaire) { create(:gestionnaire) }
      let(:commentaire) { create(:commentaire_groupe_gestionnaire, sender: administrateurs(:default_admin), gestionnaire: gestionnaire, body: 'Second message') }

      it 'should display gestionnaire\'s email' do
        is_expected.to have_text(gestionnaire.email)
      end

      describe 'delete message button for gestionnaire' do
        let(:connected_user) { gestionnaire }
        let(:form_url) { component.helpers.gestionnaire_groupe_gestionnaire_commentaire_path(groupe_gestionnaire, commentaire, statut: 'a-suivre') }

        context 'when commentaire had been written by connected gestionnaire' do
          it { is_expected.to have_selector("form[action=\"#{form_url}\"]") }
        end

        context 'when commentaire had been written by connected gestionnaire and discarded' do
          let(:commentaire) { create(:commentaire_groupe_gestionnaire, sender: administrateurs(:default_admin), gestionnaire: gestionnaire, body: 'Second message', discarded_at: 2.days.ago) }

          it do
            is_expected.not_to have_selector("form[action=\"#{form_url}\"]")
            is_expected.to have_selector(".rich-text", text: component.t('.deleted_body'))
          end
        end

        context 'on a procedure where commentaire had been written another gestionnaire' do
          let(:commentaire) { create(:commentaire_groupe_gestionnaire, sender: administrateurs(:default_admin), gestionnaire: create(:gestionnaire), body: 'Second message') }

          it { is_expected.not_to have_selector("form[action=\"#{form_url}\"]") }
        end
      end
    end

    describe '#commentaire_from_guest?' do
      subject { component.send(:commentaire_from_guest?) }

      it { is_expected.to be false }
    end

    describe '#commentaire_date' do
      let(:present_date) { Time.zone.local(2018, 9, 2, 10, 5, 0) }
      let(:creation_date) { present_date }
      let(:commentaire) do
        travel_to(creation_date) { create(:commentaire_groupe_gestionnaire, sender: administrateurs(:default_admin)) }
      end

      subject do
        travel_to(present_date) { component.send(:commentaire_date) }
      end

      it 'formats as numeric date with year' do
        expect(subject).to eq 'Le 02/09/2018 10:05'
      end

      context 'when displaying a commentaire created on a previous year' do
        let(:creation_date) { present_date.prev_year }
        it 'formats as numeric date with previous year' do
          expect(subject).to eq 'Le 02/09/2017 10:05'
        end
      end

      context 'when formatting the first day of the month' do
        let(:present_date) { Time.zone.local(2018, 9, 1, 10, 5, 0) }
        it 'formats as numeric date for first day of month' do
          expect(subject).to eq 'Le 01/09/2018 10:05'
        end
      end
    end

    describe '#correction_badge' do
      subject { component.send(:correction_badge) }

      it { is_expected.to eq nil }
    end
  end
end
