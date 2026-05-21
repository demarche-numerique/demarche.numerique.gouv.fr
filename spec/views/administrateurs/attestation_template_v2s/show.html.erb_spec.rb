# frozen_string_literal: true

describe 'administrateurs/attestation_template_v2s/show', type: :view do
  let(:attestation_template) do
    build_stubbed(:attestation_template, :v2, official_layout: false, footer: nil, label_direction: nil)
  end

  before do
    assign(:attestation_template, attestation_template)
    assign(:signature, nil)
  end

  context "quand le corps contient un lien Tiptap" do
    let(:body_with_link) do
      '<p><a href="https://demarche.numerique.gouv.fr/commencer/dossier-inscription-en-ligne-des-escadrilles-air-jeunesse-2026" target="_blank" rel="noopener noreferrer">https://demarche.numerique.gouv.fr/commencer/dossier-inscription-en-ligne-des-escadrilles-air-jeunesse-2026</a></p>'
    end

    before { assign(:body, body_with_link) }

    it "conserve la balise <a href> pour que Weasyprint génère une annotation de lien PDF correcte" do
      render
      expect(rendered).to include('href="https://demarche.numerique.gouv.fr/commencer/dossier-inscription-en-ligne-des-escadrilles-air-jeunesse-2026"')
    end
  end
end
