# frozen_string_literal: true

RSpec.describe Dossiers::ChampsRowsShowComponent, type: :component do
  let(:procedure) do
    create(:procedure, :published, types_de_champ_public: [
      { type: :repetition, libelle: "Titre bloc répétable", children: [{ type: :text, libelle: "Texte court" }] },
    ])
  end
  let(:dossier) { create(:dossier, procedure:, populate_champs: true) }
  let(:champs) { dossier.root_public_champs }

  before { render_inline(component).to_html }

  describe "repeatable block title heading hierarchy" do
    context "with default repetition_heading_level (h3)" do
      let(:component) do
        described_class.new(champs:, profile: "usager", seen_at: nil, repetition_heading_level: 3)
      end

      it "renders repeatable block titles as h3 for accessibility" do
        expect(page).to have_selector("h3.fr-h6.fr-text--bold", text: /Titre bloc répétable 1 :/)
        expect(page).to have_selector("h3.fr-h6.fr-text--bold", text: /Titre bloc répétable 2 :/)
      end
    end

    context "with repetition_heading_level 4" do
      let(:component) do
        described_class.new(champs:, profile: "usager", seen_at: nil, repetition_heading_level: 4)
      end

      it "renders repeatable block titles as h4" do
        expect(page).to have_selector("h4.fr-h6.fr-text--bold", text: /Titre bloc répétable 1 :/)
      end
    end
  end

  describe "modified badge" do
    let(:procedure) do
      create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: "Texte" }])
    end
    let(:dossier) do
      create(:dossier, :en_instruction, :with_populated_champs, procedure:).tap do |dossier|
        dossier.update_columns(depose_at: 2.weeks.ago, last_champ_updated_at: nil)
      end.reload
    end
    let(:champs) do
      dossier.root_public_champs.tap { it.first.update_columns(champ_attributes) }
    end
    let(:component) { described_class.new(champs:, profile: "instructeur", seen_at: nil) }

    context "when the champ was not modified since the dossier was deposited" do
      let(:champ_attributes) { { updated_at: 3.weeks.ago, value_updated_at: 3.weeks.ago } }

      it { expect(page).not_to have_text("Modifié le") }
    end

    context "when only machinery bumped updated_at after deposit (attachment purge, external data fetch…)" do
      let(:champ_attributes) { { updated_at: 1.day.ago, value_updated_at: 3.weeks.ago } }

      it { expect(page).not_to have_text("Modifié le") }
    end

    context "when the user modified the champ after deposit" do
      let(:champ_attributes) { { updated_at: 1.day.ago, value_updated_at: 1.day.ago } }

      it { expect(page).to have_text("Modifié le") }
    end

    context "when a legacy champ has no value_updated_at" do
      let(:champ_attributes) { { updated_at: 1.day.ago, value_updated_at: nil } }

      it "falls back to updated_at" do
        expect(page).to have_text("Modifié le")
      end
    end
  end

  describe "prefilled badge flex wrapper" do
    let(:dossier) { dossiers.en_construction }
    let(:prefill_attrs) { {} }
    let(:champs) do
      dossier.root_public_champs.tap do |cs|
        cs.first.update!(value: "ACME", **prefill_attrs)
      end
    end
    let(:component) { described_class.new(champs:, profile: "instructeur", seen_at: nil) }

    context "when the champ is not prefilled" do
      it "does not wrap the value in a flex row so block content keeps full width" do
        expect(page).to have_css(".champ-content")
        expect(page).not_to have_css(".champ-content > div.flex")
      end
    end

    context "when the champ is prefilled from a referentiel" do
      let(:prefill_attrs) { { prefilled: true, prefilled_original_value: { "value" => "ACME" } } }

      it "wraps the value and the badge in a flex row" do
        expect(page).to have_css(".champ-content > div.flex.wrap")
        expect(page).to have_css(".fr-icon-checkbox-circle-line")
      end
    end
  end
end
