# frozen_string_literal: true

class Brevo::EmailPayload
  def initialize(mail)
    @mail = mail
  end

  # Converts the Mail::Message into the JSON body of POST /v3/smtp/email.
  def to_h
    {
      sender: address(@mail[:from].addrs.first),
      subject: @mail.subject,
      htmlContent: @mail.html_part.decoded,
      textContent: @mail.text_part.decoded,
      replyTo: @mail[:reply_to]&.then { address(it.addrs.first) },
      attachment: attachments.presence,
      tags: [@mail[PriorityDeliveryConcern::MAILER_HEADER].value],
      headers: { idempotencyKey: Current.mail_idempotency_key }.compact.presence,
      **recipients,
    }.compact
  end

  private

  # Brevo requires a To: a bcc-only mail becomes one message version per
  # recipient, each with that recipient as its To.
  def recipients
    if @mail.to_addrs.empty?
      { messageVersions: @mail.bcc_addrs.map { { to: [{ email: it }] } } }
    else
      {
        to: emails(@mail.to_addrs),
        cc: emails(@mail.cc_addrs).presence,
        bcc: emails(@mail.bcc_addrs).presence,
      }
    end
  end

  def emails(addresses) = addresses.map { { email: it } }

  def address(mail_address)
    { email: mail_address.address, name: mail_address.display_name }.compact
  end

  def attachments
    @mail.attachments.map { { name: it.filename, content: Base64.strict_encode64(it.decoded) } }
  end
end
