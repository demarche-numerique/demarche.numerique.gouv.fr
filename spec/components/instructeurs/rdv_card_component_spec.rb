# frozen_string_literal: true

RSpec.describe Instructeurs::RdvCardComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:component) { described_class.new(rdv:) }

  subject do
    render_inline(component)
  end

  let(:current_instructeur) { create(:instructeur) }
  let(:dossier) { create(:dossier, :en_instruction) }
  let(:rdv) {
    {
      "url_for_agents" => "https://rdv.anct.gouv.fr/rdvs/123456",
      "starts_at" => "2025-06-04 11:30:00 +0200",
      "motif" => { "location_type" => location_type },
      "agents" => [{ "id" => 1957, "email" => current_instructeur.email, "first_name" => "Tom", "last_name" => "Plop" }],
    }
  }
  let(:starts_at) { Time.zone.parse(rdv["starts_at"]) }
  let(:location_type) { "phone" }

  before do
    allow(component).to receive(:current_instructeur).and_return(current_instructeur)
  end

  describe "rendering" do
    it "displays appointment information" do
      expect(subject).to have_css("span.fr-icon-calendar-fill")
      expect(subject).to have_text(DateFormatHelper.human(starts_at))
    end

    it "displays the owner information" do
      expect(subject).to have_css("span.fr-icon-user-fill")
      expect(subject).to have_text("Instructeur :\n\n#{component.owner}")
    end

    it "renders with agent URL" do
      expect(subject).to have_link(href: "https://rdv.anct.gouv.fr/rdvs/123456")
    end
  end

  describe "#icon_class" do
    let(:component) { described_class.new(rdv: rdv) }

    context "when location_type is phone" do
      let(:location_type) { "phone" }

      it "returns the phone icon class" do
        expect(component.icon_class).to eq("fr-icon-phone-fill")
      end
    end

    context "when location_type is visio" do
      let(:location_type) { "visio" }

      it "returns the video icon class" do
        expect(component.icon_class).to eq("fr-icon-vidicon-fill")
      end
    end

    context "when location_type is home" do
      let(:location_type) { "home" }

      it "returns the home icon class" do
        expect(component.icon_class).to eq("fr-icon-home-4-fill")
      end
    end

    context "when location_type is something else" do
      let(:location_type) { "other" }

      it "returns nil" do
        expect(component.icon_class).to be_nil
      end
    end
  end
end
