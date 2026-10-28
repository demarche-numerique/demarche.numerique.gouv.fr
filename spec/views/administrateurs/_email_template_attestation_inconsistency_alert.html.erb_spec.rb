# frozen_string_literal: true

describe 'admin/_email_template_attestation_inconsistency_alert', type: :view do
  def render_alert(procedure, mail_type)
    inconsistency = procedure.attestation_tag_inconsistency(mail_type.to_sym)
    return '' if inconsistency.nil?

    assign(:procedure, procedure)
    render partial: 'admin/email_template_attestation_inconsistency_alert',
           locals: { procedure:, inconsistency:, mail_type:, attestation_template_v1: false }
    rendered
  end

  context 'email_accepte / acceptation' do
    let(:mail_type) { 'acceptation' }

    context 'when there is no inconsistency' do
      let(:procedure) { create(:procedure, email_accepte: build(:email_accepte, body: '')) }

      it 'renders nothing' do
        expect(render_alert(procedure, mail_type)).to be_empty
      end
    end

    context 'when there is no active attestation but the mail template mentions one' do
      let(:mail) { create(:email_accepte, body: '--lien attestation--') }
      let(:procedure) { create(:procedure, email_accepte: mail, attestation_acceptation_template: nil) }

      it 'includes extraneous_tag alert text' do
        expect(render_alert(procedure, mail_type).squish)
          .to include("Cette démarche ne comporte pas d’attestation, mais l’accusé d’acceptation en mentionne une")
      end

      it 'includes mail template edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_email_template_path(procedure, 'accepte'))
      end

      it 'includes attestation edit link (V2 if needed)' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation))
      end
    end

    context 'when there is an active attestation but the mail template does not mention it' do
      let(:mail) { create(:email_accepte) }
      let(:attestation) { build(:attestation_template, activated: true, kind: :acceptation) }
      let(:procedure) { create(:procedure, email_accepte: mail, attestation_acceptation_template: attestation) }

      it 'includes missing_tag alert text' do
        expect(render_alert(procedure, mail_type).squish)
          .to include("Cette démarche comporte une attestation, mais l’accusé d’acceptation ne la mentionne pas")
      end

      it 'explains how to insert the tag with the editor' do
        alert = strip_tags(render_alert(procedure, mail_type)).squish
        expect(alert).to include("insérez la balise « lien attestation » dans l’accusé d’acceptation (tapez @ dans le corps de l’email)")
        expect(alert).not_to include("--lien attestation--")
      end

      it 'includes mail template edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_email_template_path(procedure, 'accepte'))
      end

      context 'when procedure is draft' do
        it 'can disable attestation' do
          expect(render_alert(procedure, mail_type))
            .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation))
        end
      end
    end

    context 'when only the combined declarative template misses the attestation tag' do
      let(:attestation) { build(:attestation_template, activated: true, kind: :acceptation) }
      let(:procedure) { create(:procedure, declarative_with_state: :accepte, attestation_acceptation_template: attestation) }

      before do
        create(:email_accepte, procedure:, body: '--lien attestation--')
        create(:email_depose_et_accepte, procedure:, body: 'aucun tag ici')
        procedure.reload
      end

      it 'links to the combined template edit page' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_email_template_path(procedure, Emails::DeposeEtAccepte::SLUG))
      end

      it 'names the combined template' do
        expect(render_alert(procedure, mail_type).squish)
          .to include("mais l’accusé de réception avec passage automatique au statut « accepté » ne la mentionne pas")
      end
    end
  end

  context 'email_refuse / refus' do
    let(:mail_type) { 'refus' }

    context 'when there is no inconsistency' do
      let(:procedure) { create(:procedure, email_refuse: build(:email_refuse, body: '')) }

      it 'renders nothing' do
        expect(render_alert(procedure, mail_type)).to be_empty
      end
    end

    context 'when there is no active attestation but the mail template mentions one' do
      let(:mail) { create(:email_refuse, body: '--lien attestation--') }
      let(:attestation) { build(:attestation_template, activated: false, kind: :refus) }
      let(:procedure) { create(:procedure, email_refuse: mail, attestation_refus_template: attestation) }

      it 'includes extraneous_tag alert text' do
        expect(render_alert(procedure, mail_type).squish)
          .to include("Cette démarche ne comporte pas d’attestation, mais l’accusé de refus en mentionne une")
      end

      it 'includes mail template edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_email_template_path(procedure, 'refuse'))
      end

      it 'includes attestation edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :refus))
      end
    end

    context 'when there is an active attestation but the mail template does not mention it' do
      let(:mail) { create(:email_refuse) }
      let(:attestation) { build(:attestation_template, activated: true, kind: :refus) }
      let(:procedure) { create(:procedure, email_refuse: mail, attestation_refus_template: attestation) }

      it 'includes missing_tag alert text' do
        expect(render_alert(procedure, mail_type).squish)
          .to include("Cette démarche comporte une attestation, mais l’accusé de refus ne la mentionne pas :")
      end

      it 'includes mail template edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_email_template_path(procedure, 'refuse'))
      end

      it 'includes attestation edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :refus))
      end
    end
  end
end
