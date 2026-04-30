# frozen_string_literal: true

require "rails_helper"

RSpec.describe SwitchDomainBannerComponent, type: :component do
  let(:app_host_legacy) { "demarches-simplifiees.fr" }
  let(:app_host) { "demarche.numerique.gouv.fr" }
  let(:request_host) { app_host }

  let(:user) { create(:user) }
  let(:request_host) { app_host_legacy }
  let(:path) { "/" }

  before do
    allow(Current).to receive(:host).and_return(request_host)
    stub_const("ApplicationHelper::APP_HOST_LEGACY", app_host_legacy)
    stub_const("ApplicationHelper::APP_HOST", app_host)

    Flipper.enable(:switch_domain)
  end

  after do
    Flipper.disable(:switch_domain)
  end

  subject(:rendered) do
    with_request_url path, host: request_host do
      render_inline(described_class.new(user: user))
    end
  end

  context "when request is already on APP_HOST" do
    let(:request_host) { app_host }

    it "does not render the banner" do
      expect(rendered.to_html).to be_empty
    end
  end

  describe "URL generation" do
    let(:path) { "/admin/procedures" }
    let(:request_host) { app_host_legacy }

    it "generate an url to the new domain" do
      expect(rendered.to_html).to have_link("demarche.numerique.gouv.fr", href: "http://demarche.numerique.gouv.fr/admin/procedures")
      expect(rendered.to_html).not_to include("window.location")
      expect(rendered.to_html).to include("Suivez ce lien")
    end

    context "when a stored location exists" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:get_stored_location_for)
          .with(:user).and_return("/procedures/123/dossiers")
      end

      it "uses the stored location in the redirect URL" do
        expect(rendered.to_html).to have_link("demarche.numerique.gouv.fr",
          href: "//demarche.numerique.gouv.fr/procedures/123/dossiers")
      end
    end
  end
end
