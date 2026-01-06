# frozen_string_literal: true

describe EditableChamp::QuotientFamilialComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :quotient_familial }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = described_class.new(champ:, form:)
    end

    render_inline(component)
  end

  context "when dossier is for preview" do
    before { dossier.update(for_procedure_preview: true) }

    it "offers two viewing options" do
      expect(subject).to have_field("Usager connecté via FranceConnect et QF récupéré", type: 'radio')
      expect(subject).to have_field("Usager non connecté via FranceConnect ou QF non récupéré", type: 'radio')
    end
  end

  context "when data have been recovered from API Particulier" do
    let(:data) {
      {
        "quotient_familial": {
          "valeur": 464,
          "mois": 12,
          "annee": 2023,
          "fournisseur": "CAF",
          "mois_calcul": 12,
          "annee_calcul": 2023,
        },
      }
    }

    before { champ.update(value_json: data, external_state: 'fetched') }

    it 'renders data from API Particulier' do
      expect(subject).to have_text("Quotient familial CAF")
    end

    it 'requires confirmation of the accuracy of the data' do
      expect(subject).to have_text('Ces informations sont-elles correctes ?')
      expect(subject).to have_field("Oui", type: 'radio')
      expect(subject).to have_field("Non", type: 'radio')
    end

    context 'when user does not confirm the accuracy of the information' do
      before { champ.update(value: false) }

      it 'renders piece justifcative input' do
        expect(subject).to have_text('Justificatif de quotient familial')
        expect(subject).to have_css('input[type="file"]')
      end
    end
  end

  context "when data have not been recovered from API Particulier" do
    context "when there was an external_error" do
      before { champ.update(external_state: 'external_error') }

      it 'renders piece justifcative input' do
        expect(subject).to have_text('Justificatif de quotient familial')
        expect(subject).to have_css('input[type="file"]')
      end
    end

    context "when the champ is not ready for external call" do
      before { champ.update(external_state: 'idle') }

      it 'renders piece justifcative input' do
        expect(subject).to have_text('Justificatif de quotient familial')
        expect(subject).to have_css('input[type="file"]')
      end
    end
  end
end
