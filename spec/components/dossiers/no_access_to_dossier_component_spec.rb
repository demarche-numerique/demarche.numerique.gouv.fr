# frozen_string_literal: true

RSpec.describe Dossiers::NoAccessToDossierComponent, type: :component do
  let(:instructeur) { create(:instructeur, email: instructeur_email) }
  let(:instructeur_email) { "agent@inst.com" }
  let(:procedure) { create(:procedure) }
  let(:dossier) { create(:dossier, procedure:) }

  subject { render_inline(described_class.new(dossier, instructeur)) }

  it_behaves_like "a labelled DSFR modal", "modal-no-access-to-dossier-1" do
    let(:modal_html) { subject.to_html }

    before { allow(dossier).to receive(:id).and_return(1) }
  end

  it "renders the dossier number as the modal trigger link" do
    expect(subject).to have_link("Dossier n° #{dossier.id}", href: "#modal-no-access-to-dossier-#{dossier.id}")
  end

  it "renders the modal title" do
    expect(subject).to have_text("Vous n’avez pas accès à ce dossier")
  end

  context "when an administrateur shares the instructeur email domain" do
    let(:instructeur_email) { "agent@shared-domain.gouv.fr" }
    let(:matching_admin) { create(:administrateur, email: "boss@SHARED-domain.gouv.fr") }
    let(:other_admin) { create(:administrateur, email: "chief@elsewhere.com") }
    let(:procedure) { create(:procedure, administrateurs: [matching_admin, other_admin]) }
    let(:dossier) { create(:dossier, procedure:) }

    it "lists only the matching administrateur email (case-insensitive domain)" do
      expect(subject).to have_link(matching_admin.email, href: "mailto:#{matching_admin.email}")
      expect(subject).to have_no_link(href: "mailto:#{other_admin.email}")
    end

    it "names the procedure in the modal content" do
      expect(subject).to have_text(procedure.libelle)
    end
  end

  context "when no administrateur shares the instructeur email domain" do
    let(:instructeur_email) { "agent@other-domain.gouv.fr" }
    let(:procedure) { procedures.brouillon }
    let(:dossier) { create(:dossier, procedure:) }

    it "exposes no administrateur email" do
      procedure.administrateurs.each do |admin|
        expect(subject).to have_no_link(href: "mailto:#{admin.email}")
      end
    end

    it "invites to contact the service and shows its contact info" do
      expect(subject).to have_text("Contactez le service en charge de la démarche")
      expect(subject).to have_text(procedure.service.nom)
      expect(subject).to have_link(procedure.service.email, href: "mailto:#{procedure.service.email}")
    end
  end
end
