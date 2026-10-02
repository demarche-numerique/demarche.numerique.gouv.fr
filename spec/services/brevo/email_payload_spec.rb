# frozen_string_literal: true

describe Brevo::EmailPayload do
  def payload_for(mail) = described_class.new(mail).to_h

  let(:mail) do
    Mail.new(from: 'Démarche Numérique <no-reply@example.gouv.fr>', to: 'usager@example.com', subject: 'Votre dossier').tap do |m|
      m[PriorityDeliveryConcern::MAILER_HEADER] = 'DossierMailer.notify_new_answer'
      m.html_part = Mail::Part.new { content_type 'text/html; charset=UTF-8'; body '<p>Bonjour</p>' }
      m.text_part = Mail::Part.new { body 'Bonjour' }
    end
  end

  it 'maps sender, recipient, subject, both bodies and the mailer tag' do
    expect(payload_for(mail)).to eq(
      sender: { email: 'no-reply@example.gouv.fr', name: 'Démarche Numérique' },
      to: [{ email: 'usager@example.com' }],
      subject: 'Votre dossier',
      htmlContent: '<p>Bonjour</p>',
      textContent: 'Bonjour',
      tags: ['DossierMailer.notify_new_answer']
    )
  end

  it 'maps reply_to, cc, bcc, attachments and the idempotency key' do
    mail.reply_to = 'Démarche Numérique <ne-pas-repondre@example.gouv.fr>'
    mail.cc = 'cc@example.com'
    mail.bcc = 'bcc@example.com'
    mail.add_file(filename: 'attestation.pdf', content: '%PDF-1.4')

    payload = Current.set(mail_idempotency_key: 'job-uuid') { payload_for(mail) }

    expect(payload).to include(
      replyTo: { email: 'ne-pas-repondre@example.gouv.fr', name: 'Démarche Numérique' },
      cc: [{ email: 'cc@example.com' }],
      bcc: [{ email: 'bcc@example.com' }],
      attachment: [{ name: 'attestation.pdf', content: Base64.strict_encode64('%PDF-1.4') }],
      headers: { idempotencyKey: 'job-uuid' }
    )
  end

  it 'sends a bcc-only mail as one message version per recipient' do
    mail.to = nil
    mail.bcc = ['a@example.com', 'b@example.com']

    payload = payload_for(mail)

    expect(payload).to include(messageVersions: [{ to: [{ email: 'a@example.com' }] }, { to: [{ email: 'b@example.com' }] }])
    expect(payload).not_to have_key(:to)
    expect(payload).not_to have_key(:bcc)
  end
end
