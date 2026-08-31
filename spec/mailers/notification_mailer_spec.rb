# frozen_string_literal: true

RSpec.describe NotificationMailer, type: :mailer do
  let(:administrateur) { administrateurs.default }
  let(:user) { create(:user) }
  let(:procedure) { procedures.individual }

  describe 'send_notification_for_tiers' do
    let(:dossier_for_tiers) { create(:dossier, :en_construction, :for_tiers_with_notification, procedure: procedures.individual) }

    subject { described_class.send_notification_for_tiers(dossier_for_tiers) }

    it 'verifies email subject, recipient, and body content for updated dossier by mandataire' do
      expect(subject.subject).to include(I18n.t("notification_mailer.send_notification_for_tiers.subject", first_name: dossier_for_tiers.mandataire_first_name, last_name: dossier_for_tiers.mandataire_last_name))
      expect(subject.to).to eq([dossier_for_tiers.individual.email])
      expect(subject.body).to include("a été déposé le")
      expect(subject.body).to include("Pour en savoir plus, veuillez vous rapprocher de\r\n<a href=\"mailto:#{dossier_for_tiers.user.email}\">#{dossier_for_tiers.user.email}</a>.")
    end
  end

  describe 'send_notification_for_tiers for repasser_en_instruction' do
    let(:dossier_for_tiers) { create(:dossier, :accepte, :for_tiers_with_notification, procedure: procedures.individual) }

    subject { described_class.send_notification_for_tiers(dossier_for_tiers, repasser_en_instruction: true) }

    it 'verifies email subject, recipient, and body content for dossier re-examination notification' do
      expect(subject.subject).to include(I18n.t("notification_mailer.send_notification_for_tiers.subject", first_name: dossier_for_tiers.mandataire_first_name, last_name: dossier_for_tiers.mandataire_last_name))
      expect(subject.to).to eq([dossier_for_tiers.individual.email])
      expect(subject.body).to include("va être réexaminé, la précédente décision sur ce dossier est caduque.")
      expect(subject.body).to include("Pour en savoir plus, veuillez vous rapprocher de\r\n<a href=\"mailto:#{dossier_for_tiers.user.email}\">#{dossier_for_tiers.user.email}</a>.")
    end
  end

  describe 'send_notification_for_tiers with accuse lecture procedure' do
    let(:dossier_for_tiers) { create(:dossier, :accepte, :for_tiers_with_notification, procedure: create(:procedure, :accuse_lecture, :for_individual)) }

    subject { described_class.send_notification_for_tiers(dossier_for_tiers) }

    it 'sends proper notification for tiers with correct subject, recipient, and body content' do
      expect(subject.subject).to include(I18n.t("notification_mailer.send_notification_for_tiers.subject", first_name: dossier_for_tiers.mandataire_first_name, last_name: dossier_for_tiers.mandataire_last_name))
      expect(subject.to).to eq([dossier_for_tiers.individual.email])
      expect(subject.body).to include("a été traité le")
      expect(subject.body).to include("Pour en savoir plus, veuillez vous rapprocher de\r\n<a href=\"mailto:#{dossier_for_tiers.user.email}\">#{dossier_for_tiers.user.email}</a>.")
    end
  end

  describe 'send_accuse_lecture_notification' do
    let(:dossier) { create(:dossier, :accepte, procedure: create(:procedure, :accuse_lecture)) }
    subject { described_class.send_accuse_lecture_notification(dossier) }

    it "works" do
      expect(subject.subject).to include(I18n.t("notification_mailer.send_accuse_lecture_notification.subject", dossier_id: dossier.id, libelle: dossier.procedure.libelle))
      expect(subject.body).to include("Pour en connaitre la nature, veuillez consulter votre dossier dans votre compte #{APPLICATION_NAME}")
      expect(subject.body).to have_link("Consulter mon dossier", href: dossier_url(dossier))
    end
  end

  describe 'send_en_construction_notification' do
    before { stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake') }

    let(:dossier) { create(:dossier, :en_construction, :with_individual, user: user, procedure:) }

    subject(:mail) { described_class.send_en_construction_notification(dossier) }

    let(:body) { (mail.html_part || mail).body }

    context "without custom template" do
      it 'renders default template' do
        expect(mail.subject).to eq("Votre dossier n° #{dossier.id} a bien été déposé (#{procedure.libelle})")
        expect(body).to include("Votre dossier n°&nbsp;#{dossier.id}")
        expect(body).to include(procedure.service.nom)
        expect(body).to include(procedure.service.adresse)
        expect(body).to include(procedure.service.faq_link)
        expect(body).to include(procedure.service.contact_link)
        expect(body).to include(messagerie_dossier_url(dossier))
        expect(body).to include(procedure.service.telephone)
        expect(body).to include(procedure.service.horaires.sub(/\S/, &:downcase))
        expect(body).to include(procedure.service.other_contact_info)
        expect(mail.attachments.first.filename).to eq("attestation-depot_dossier-#{dossier.id}.pdf")
      end
    end

    context "when the attestation generation fails" do
      before do
        allow(TypstService).to receive(:generate_pdf).and_raise(TypstService::Error, 'PDF generation failed')
      end

      it 'still sends the notification, without the attachment' do
        expect(mail.subject).to eq("Votre dossier n° #{dossier.id} a bien été déposé (#{procedure.libelle})")
        expect(mail.attachments).to be_empty
      end
    end

    context "with a custom template" do
      let(:email_template) { create(:email_depose, subject: 'Email subject', body: 'Your dossier was received. Thanks.', procedure:) }

      before do
        dossier.procedure.email_depose = email_template
      end

      it 'renders the template' do
        expect(mail.subject).to eq('Email subject')
        expect(body).to include('Your dossier was received')
        expect(mail.attachments.first.filename).to eq("attestation-depot_dossier-#{dossier.id}.pdf")
      end
    end

    context "with contact information" do
      let(:procedure) { create(:simple_procedure, :routee) }

      let!(:contact_information) {
        create(:contact_information, groupe_instructeur: procedure.groupe_instructeurs.first)
      }

      before do
        dossier.update!(groupe_instructeur: procedure.groupe_instructeurs.first)
      end

      it 'renders default template' do
        expect(mail.subject).to eq("Votre dossier n° #{dossier.id} a bien été déposé (#{procedure.libelle})")
        expect(body).to include("Votre dossier n°&nbsp;#{dossier.id}")
        expect(body).to include(contact_information.telephone_url)
        expect(body).to include(contact_information.adresse)
      end
    end
  end

  describe 'JDMA button' do
    let(:monavis_embed) do
      '<a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?nd_source=button&key=abc"><img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu-clair.svg" /></a>'
    end
    let(:procedure) { create(:simple_procedure, :with_service, monavis_embed:) }
    let(:body) { (mail.html_part || mail).body }

    context 'en_construction (accusé de réception)' do
      before { stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake') }

      let(:dossier) { create(:dossier, :en_construction, :with_individual, user: user, procedure:) }

      subject(:mail) { described_class.send_en_construction_notification(dossier) }

      it 'includes the JDMA feedback link with source=email and the Services Publics + logo' do
        expect(body).to include('nd_source=email')
        expect(body).to include('Je donne mon avis sur cette démarche')
        expect(body).to include('logo-services-plus')
      end
    end

    context 'on a decision email without a procedure embed' do
      let(:monavis_embed) { nil }
      let(:dossier) { create(:dossier, :accepte, :with_individual, user: user, procedure:) }

      subject(:mail) { described_class.send_accepte_notification(dossier) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SERVICES_PUBLICS_PLUS_URL').and_return(instance_wide_url)
      end

      context 'with the instance-wide url configured' do
        let(:instance_wide_url) { 'https://www.plus.transformation.gouv.fr/experience' }

        it 'falls back to the instance-wide feedback link' do
          expect(body).to include('Comment s’est passée cette démarche ?')
          expect(body).to include(instance_wide_url)
        end
      end

      context 'without the instance-wide url' do
        let(:instance_wide_url) { nil }

        it 'omits the feedback block' do
          expect(body).not_to include('Comment s’est passée cette démarche ?')
        end
      end
    end

    context 'on the receipt email without a procedure embed' do
      let(:monavis_embed) { nil }
      let(:dossier) { create(:dossier, :en_construction, :with_individual, user: user, procedure:) }

      subject(:mail) { described_class.send_en_construction_notification(dossier) }

      before do
        stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake')
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SERVICES_PUBLICS_PLUS_URL').and_return('https://www.plus.transformation.gouv.fr/experience')
      end

      it 'omits the feedback block rather than falling back' do
        expect(body).not_to include('Comment s’est passée cette démarche ?')
      end
    end

    context 'with both the procedure embed and the instance-wide url' do
      let(:dossier) { create(:dossier, :accepte, :with_individual, user: user, procedure:) }

      subject(:mail) { described_class.send_accepte_notification(dossier) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SERVICES_PUBLICS_PLUS_URL').and_return('https://www.plus.transformation.gouv.fr/experience')
      end

      it 'gives priority to the procedure link' do
        expect(body).to include('nd_source=email')
        expect(body).not_to include('plus.transformation.gouv.fr')
      end
    end
  end

  describe 'send_en_instruction_notification' do
    let(:dossier) { create(:dossier, :en_instruction, :with_individual, :with_service, user: user, procedure:) }
    let(:email_template) { create(:email_passe_en_instruction, subject: 'Email subject', body: 'Your dossier was processed. Thanks.', procedure:) }

    before do
      dossier.procedure.email_passe_en_instruction = email_template
    end

    subject(:mail) { described_class.send_en_instruction_notification(dossier) }

    it 'renders the template with subject and body' do
      expect(mail.subject).to eq('Email subject')
      expect(mail.body).to include('Your dossier was processed')
      expect(mail.body).to have_link('messagerie')
    end

    it 'renders the actions with links to dossier and messagerie' do
      expect(mail.body).to have_link('Consulter mon dossier', href: dossier_url(dossier))
      expect(mail.body).to have_link('J’ai une question', href: messagerie_dossier_url(dossier))
    end

    context 'when the template body contains tags' do
      let(:email_template) { create(:email_passe_en_instruction, subject: 'Email subject', body: 'Hello --nom--, your dossier --lien dossier-- was processed.', procedure:) }

      it 'replaces value tags with the proper value and renders links correctly' do
        expect(mail.body).to include(dossier.individual.nom)
        expect(mail.body).to have_link(href: dossier_url(dossier))
      end
    end

    context 'when the template body contains HTML' do
      let(:email_template) { create(:email_passe_en_instruction, body: 'Your <b>dossier</b> was processed. <iframe src="#">Foo</iframe>', procedure:) }

      it 'allows basic formatting tags but sanitizes sensitive content' do
        expect(mail.body).to include('<b>dossier</b>')
        expect(mail.body).not_to include('iframe')
      end
    end

    context 'when the template body comes from json_body with a dossier_url mention' do
      let(:email_template) do
        create(:email_passe_en_instruction, subject: 'Email subject', procedure:, json_body: {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
              "content" => [
                { "type" => "mention", "attrs" => { "id" => "dossier_url", "label" => "lien dossier" } },
              ],
            },
          ],
        })
      end

      it 'renders the link tag as clickable HTML' do
        expect(mail.body.encoded).to include('<a ')
        expect(mail.body).to have_link(href: dossier_url(dossier))
      end
    end

    it 'sends the mail from a no-reply address' do
      expect(subject.from.first).to eq(Mail::Address.new(NO_REPLY_EMAIL).address)
    end
  end

  describe 'subject length' do
    let(:procedure) { create(:simple_procedure, libelle: "My super long title " + ("xo " * 100)) }
    let(:dossier) { create(:dossier, :accepte, :with_individual, :with_service, user: user, procedure:) }
    let(:email_template) { create(:email_accepte, subject:, body: 'Your dossier was accepted. Thanks.', procedure:) }

    before do
      dossier.procedure.email_accepte = email_template
    end

    subject(:mail) { described_class.send_accepte_notification(dossier) }

    context "when the subject is too long" do
      let(:subject) { 'Un long libellé --libellé démarche--' }
      it { expect(mail.subject.length).to be <= 100 }
    end

    context "when the subject should fallback to default" do
      let(:subject) { "" }
      it 'provides a default subject within the length limit including procedure title beginning' do
        expect(mail.subject).to match(/^Votre dossier .+ a été accepté \(My super long title/)
        expect(mail.subject.length).to be <= 100
      end
    end
  end

  describe 'subject with apostrophe' do
    let(:procedure) { create(:simple_procedure, libelle: "Mon titre avec l’apostrophe") }
    let(:dossier) { create(:dossier, :en_instruction, :with_individual, :with_service, user: user, procedure:) }
    let(:email_template) { create(:email_passe_en_instruction, subject:, body: 'Your dossier was accepted. Thanks.', procedure:) }

    before do
      dossier.procedure.email_passe_en_instruction = email_template
    end

    subject(:mail) { described_class.send_en_instruction_notification(dossier) }

    context "when the subject has a special character that should not be escaped" do
      let(:subject) { '--libellé démarche--' }
      it 'includes the apostrophe without escaping it' do
        expect(mail.subject).to eq("Mon titre avec l’apostrophe")
      end
    end
  end
end
