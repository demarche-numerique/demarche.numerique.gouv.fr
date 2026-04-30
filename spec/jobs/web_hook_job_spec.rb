# frozen_string_literal: true

describe WebHookJob, type: :job do
  describe 'perform' do
    let(:procedure) { create(:procedure, web_hook_url:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:web_hook_url) { "https://domaine.fr/callback_url" }
    let(:job) { WebHookJob.new(procedure.id, dossier.id, dossier.state, dossier.updated_at) }

    context 'with success on webhook' do
      it 'calls webhook' do
        stub_request(:post, web_hook_url).to_return(status: 200, body: "success")
        expect { job.perform_now }.not_to raise_error
      end
    end

    context 'with error on webhook' do
      it 'reports to Sentry with sanitized URL' do
        allow(Sentry).to receive(:set_tags)
        allow(Sentry).to receive(:set_extras)
        allow(Sentry).to receive(:capture_message)
        stub_request(:post, web_hook_url).to_return(status: 500, body: "error")

        job.perform_now

        expect(Sentry).to have_received(:set_extras).with(web_hook_url: "https://domaine.fr/callback_url")
        expect(Sentry).to have_received(:capture_message)
      end
    end

    context 'when webhook URL contains query params' do
      let(:web_hook_url) { "https://domaine.fr/callback_url?token=secret123" }

      it 'strips query params from Sentry logs' do
        allow(Sentry).to receive(:set_tags)
        allow(Sentry).to receive(:set_extras)
        allow(Sentry).to receive(:capture_message)
        stub_request(:post, web_hook_url).to_return(status: 500, body: "error")

        job.perform_now

        expect(Sentry).to have_received(:set_extras).with(web_hook_url: "https://domaine.fr/callback_url")
      end
    end
  end
end
