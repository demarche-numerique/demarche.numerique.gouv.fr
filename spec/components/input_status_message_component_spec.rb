# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dsfr::InputStatusMessageComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }
  let(:champ_component) { instance_double("ChampComponent", errors_on_attribute?: errors_on_attribute, error_full_messages:, attribute: :value) }
  let(:component) { described_class.new(champ_component:, champ:) }

  subject { render_inline(component) }

  context "when there are errors on the attribute" do
    let(:types_de_champ_public) { [{ type: :text, libelle: "Plop" }] }
    let(:errors_on_attribute) { true }
    let(:error_full_messages) { ["Invalid input"] }
    it "renders the error message" do
      expect(subject).to have_css(".fr-message--error", text: "« #{champ.libelle} »")
    end

    context "when row_number is provided" do
      let(:component) { described_class.new(champ_component:, champ:, row_number: 2) }
      it "renders the error message with row number" do
        expect(subject).to have_css(".fr-message--error", text: "« [2] #{champ.libelle} »")
      end
    end
  end
  context 'without errors' do
    let(:error_full_messages) { [] }
    let(:errors_on_attribute) { false }

    context 'with rna champs' do
      let(:types_de_champ_public) { [{ type: :rna }] }
      context "when there are no errors but the field supports statut" do
        it "renders the statut message" do
          allow(champ).to receive(:title).and_return("Title")
          allow(champ).to receive(:address).and_return("123 Street")

          expect(subject).to have_css(".fr-message--info") # , text: I18n.t(".rna.data_fetched", title: "Title", address: "123 Street"))
        end
      end
    end

    context 'with dossier_link champs' do
      let(:types_de_champ_public) { [{ type: :dossier_link }] }
      let(:linked_dossier) { create(:dossier, :en_construction) }

      before do
        champ.update(value: linked_dossier.id.to_s)
      end

      context "when a dossier is found" do
        it "renders the dossier information" do
          expect(subject).to have_css(".fr-message--info", text: /Dossier/)
        end
      end

      context "when the linked dossier has been hidden by the user" do
        let(:linked_dossier) do
          create(:dossier, :en_instruction, hidden_by_user_at: Time.zone.local(2026, 3, 15))
        end

        it "renders the hidden_by_user message" do
          expect(subject).to have_css(
            ".fr-message--info",
            text: /Dossier déposé le .* sur la démarche .* mais supprimé le 15 mars 2026/
          )
        end
      end
    end

    context 'with referentiel champs' do
      let(:referentiel) { create(:api_referentiel, :exact_match) }
      let(:types_de_champ_public) { [{ type: :referentiel, referentiel: }] }
      let(:state) { :idle }

      before do
        allow(champ).to receive(:idle?).and_return((state == :idle))
        allow(champ).to receive(:pending?).and_return((state == :pending))
        allow(champ).to receive(:fetched?).and_return((state == :fetched))
        allow(champ).to receive(:external_error?).and_return((state == :external_error))
        allow(champ).to receive(:value).and_return('value')
      end

      context "when the field is a referentiel and pending? is true" do
        let(:state) { :pending }

        it "renders the pending message" do
          expect(subject).to have_css(".fr-message--info", text: "Recherche en cours.")
        end
      end

      context "when the field is a referentiel and external_error? is true" do
        let(:state) { :external_error }

        it "renders the error message 'KC'" do
          expect(subject).to have_css(".fr-message--info", text: "Aucun élément trouvé pour la référence : ")
        end
      end

      context "when the field is a referentiel and value is present" do
        let(:state) { :fetched }

        it "renders the OK message" do
          expect(subject).to have_css(".fr-message--valid", text: 'value')
        end
      end
    end

    context 'with address champs' do
      let(:types_de_champ_public) { [{ type: :address }] }
      let(:state) { :idle }

      before do
        allow(champ).to receive(:idle?).and_return((state == :idle))
        allow(champ).to receive(:pending?).and_return((state == :pending))
        allow(champ).to receive(:external_error?).and_return((state == :external_error))
        allow(champ).to receive(:external_id).and_return("20 avenue de Ségur, 75007 Paris")
      end

      context "when pending" do
        let(:state) { :pending }

        it "renders the fetching message with address" do
          expect(subject).to have_css(".fr-message--info")
          expect(subject).to have_text("20 avenue de Ségur, 75007 Paris")
        end
      end

      context "when external_error" do
        let(:state) { :external_error }

        it "renders the error message" do
          expect(subject).to have_css(".fr-message--warning")
        end
      end
    end

    context 'with piece_justificative champs (RIB)' do
      let(:types_de_champ_public) { [{ type: :piece_justificative, nature: 'rib' }] }
      let(:state) { :idle }
      let(:value_json) { {} }

      before do
        allow(champ).to receive(:idle?).and_return((state == :idle))
        allow(champ).to receive(:pending?).and_return((state == :pending))
        allow(champ).to receive(:fetched?).and_return((state == :fetched))
        allow(champ).to receive(:external_error?).and_return((state == :external_error))
        allow(champ).to receive(:value_json).and_return(value_json)
      end

      context "when the champ is pending" do
        let(:state) { :pending }

        it "renders the info message" do
          expect(subject).to have_css(".fr-message--info")
        end
      end

      context "when the state is fetched but IBAN is nil" do
        let(:state) { :fetched }
        let(:value_json) { { 'rib' => {} } }

        it "renders the warning message" do
          expect(subject).to have_css(".fr-message--warning")
        end
      end

      context "when IBAN is present" do
        let(:state) { :fetched }
        let(:iban) { "FRjesuisuniban" }
        let(:value_json) { { 'rib' => { 'iban' => iban } } }

        it "renders the valid message with IBAN" do
          expect(subject).to have_css(".fr-message--valid", text: iban)
        end
      end

      context "when OCR has an error" do
        let(:state) { :external_error }

        it "renders the warning message" do
          expect(subject).to have_css(".fr-message--warning", text: 'Une erreur')
        end
      end
    end

    context 'with siret champs' do
      let(:types_de_champ_public) { [{ type: :siret }] }
      let(:errors_on_attribute) { false }
      let(:error_full_messages) { [] }

      context "when the champ has direct validation errors (external_error with code_404)" do
        let(:form) { instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]", object: champ) }
        let(:champ_component) { EditableChamp::SiretComponent.new(form:, champ:) }

        before do
          champ.update_columns(external_id: '80879023200025', external_state: 'external_error')
          champ.errors.add(:value, :code_404)
        end

        it "renders the error message with error styling, not valid styling" do
          expect(subject).to have_css(".fr-message--error")
          expect(subject).not_to have_css(".fr-message--valid")
          expect(subject).to have_text("Résultat introuvable. Vérifiez vos informations.")
        end
      end

      context "when etablissement is non-diffusible (diffusable_commercialement: false)" do
        before do
          etablissement = create(:etablissement, :non_diffusable, entreprise_raison_sociale: "SECRET EI", entreprise_forme_juridique: "Entrepreneur individuel")
          champ.update!(value: etablissement.siret, external_id: etablissement.siret, etablissement:)
        end

        it "renders the status message with masked denomination (Non-diffusible), not the real name" do
          expect(subject).to have_css(".fr-message--info", text: "Non-diffusible")
          expect(subject).not_to have_text("SECRET EI")
        end
      end

      context "when etablissement is diffusible" do
        before do
          etablissement = create(:etablissement, diffusable_commercialement: true, entreprise_raison_sociale: "GRTGAZ", entreprise_forme_juridique: "SA")
          champ.update!(value: etablissement.siret, external_id: etablissement.siret, etablissement:)
        end

        it "renders the status message with the real denomination" do
          expect(subject).to have_css(".fr-message--info", text: "GRTGAZ")
        end
      end
    end
  end
end
