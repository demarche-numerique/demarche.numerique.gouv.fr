# frozen_string_literal: true

module AvisCreationConcern
  extend ActiveSupport::Concern

  def handle_create_avis(claimant:, dossier:, success_path:, error_template:, avis_source: nil)
    return render error_template, status: :unprocessable_content if handle_empty_emails

    sent_emails, failed_emails = CreateAvisService.call(
      claimant:,
      batch: false,
      avis: Avis.new(avis_params.merge(dossier:)),
      avis_source:,
      emails: avis_emails
    )

    if failed_emails.any?
      flash.now[:notice] = sent_emails_notice(sent_emails) if sent_emails.any?
      flash.now[:alert] = failed_emails_alert(failed_emails) if failed_emails.any?

      render error_template, status: :unprocessable_content
    else
      flash[:notice] = sent_emails_notice(sent_emails) if sent_emails.any?

      redirect_to success_path
    end
  end

  private

  def handle_empty_emails
    if avis_emails.empty?
      email_label = User.human_attribute_name(:email)
      flash.now[:alert] = format(t('errors.format'), attribute: email_label, message: t('errors.messages.blank'))
      true
    end
  end

  def avis_params
    params.require(:avis).permit(
      :introduction_file,
      :introduction,
      :confidentiel,
      :invite_linked_dossiers,
      :question_label
    )
  end

  def avis_emails
    Array(params[:avis][:emails]).map(&:strip).map(&:downcase).compact_blank
  end

  def sent_emails_notice(sent_emails)
    if sent_emails.count < 5
      t('avis_creation_concern.avis_sent.with_emails', emails: sent_emails.join(', '))
    else
      t('avis_creation_concern.avis_sent.with_count', count: sent_emails.count)
    end
  end

  def failed_emails_alert(failed_emails)
    failed_emails.map { "#{it[:email]} : #{it[:messages].join(', ')}" }.join(' | ')
  end
end
