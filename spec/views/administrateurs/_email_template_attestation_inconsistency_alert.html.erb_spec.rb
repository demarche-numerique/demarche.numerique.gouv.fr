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

      context 'when procedure is draft' do
        it 'can disable attestation' do
          expect(render_alert(procedure, mail_type))
            .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :acceptation))
        end
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

      it 'includes attestation edit link' do
        expect(render_alert(procedure, mail_type))
          .to include(edit_admin_procedure_attestation_template_v2_path(procedure, attestation_kind: :refus))
      end
    end
  end
end
