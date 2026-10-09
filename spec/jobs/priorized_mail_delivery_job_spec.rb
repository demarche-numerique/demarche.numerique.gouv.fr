# frozen_string_literal: true

RSpec.describe PriorizedMailDeliveryJob, type: :job do
  it 'does not print what a mail is handed in the Rails log' do
    output = StringIO.new
    allow(ActiveJob::Base).to receive(:logger).and_return(ActiveSupport::Logger.new(output))

    described_class.perform_later('DeviseUserMailer', 'reset_password_instructions', 'deliver_now', args: [users.usager, 'a-live-reset-token'])

    expect(output.string).to include('Enqueued PriorizedMailDeliveryJob')
    expect(output.string).not_to include('a-live-reset-token')
  end

  it 'exposes its job id as the mail idempotency key during delivery' do
    keys = []
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now) { keys << Current.mail_idempotency_key }

    job = described_class.perform_later('UserMailer', 'ask_for_merge', 'deliver_now', args: [users.usager, 'other@example.com'])
    perform_enqueued_jobs

    expect(keys).to eq([job.job_id])
  end

  it 'tags Sentry with the dossier and procedure passed as params' do
    allow(Sentry).to receive(:set_tags)
    dossier = dossiers.brouillon

    described_class.perform_later('DossierMailer', 'notify_new_draft', 'deliver_now', args: [], params: { dossier: })
    perform_enqueued_jobs

    expect(Sentry).to have_received(:set_tags).with(dossier: dossier.id, procedure: dossier.revision.procedure_id)
  end
end
