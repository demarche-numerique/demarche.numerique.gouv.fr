# frozen_string_literal: true

describe 'users/procedure_footer', type: :view do
  let(:service) { create(:service) }
  let(:dossier) {
    dossier = create(:dossier)
    dossier.procedure.service = service
    return dossier
  }

  subject { render 'users/procedure_footer', procedure: dossier.procedure, dossier: dossier }

  it "affiche les informations de contact" do
    expect(subject).to have_text(service.nom)
    expect(subject).to have_text(service.organisme)
    expect(subject).to have_text(service.telephone)
  end

  it "affiche les liens usuels requis" do
    expect(subject).to have_link("Accessibilité")
    expect(subject).to have_link("Mentions légales")
  end

  context "quand le dossier n’a pas de service associé" do
    let(:service) { nil }

    it do
      is_expected.to have_selector("footer")
      is_expected.to have_link("Accessibilité")
      is_expected.not_to have_text('téléphone')
    end
  end

  describe '#cadre_juridique' do
    context 'when an external link is provided' do
      before { dossier.procedure.update(cadre_juridique: "http://google.fr") }
      it { is_expected.to have_link("Texte cadrant la demande d’information", href: 'http://google.fr') }
    end

    context 'when there is deliberation attached' do
      before { dossier.procedure.update(cadre_juridique: nil, deliberation: fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf')) }
      it { is_expected.to have_link("Texte cadrant la demande d’information") }
    end
  end

  describe '#lien_dpo' do
    context "when there is not lien_dpo" do
      before { dossier.procedure.update(lien_dpo: nil) }
      it { is_expected.not_to have_text('Contacter le Délégué à la Protection des Données') }
    end

    context "when there is a lien_dpo with an email" do
      before { dossier.procedure.update(lien_dpo: 'dpo@beta.gouv.fr') }
      it { is_expected.to have_selector('a[href="mailto:dpo@beta.gouv.fr?subject="]') }
    end

    context "when there is a lien_dpo with a schemaless link" do
      before { dossier.procedure.update(lien_dpo: 'beta.gouv.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: '//beta.gouv.fr') }
    end

    context "when there is a lien_dpo with a link with http:// schema" do
      before { dossier.procedure.update(lien_dpo: 'http://beta.gouv.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: 'http://beta.gouv.fr') }
    end

    context "when there is a lien_dpo with a link with https:// schema" do
      before { dossier.procedure.update(lien_dpo: 'https://beta.gouv.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: 'https://beta.gouv.fr') }
    end
  end
end
