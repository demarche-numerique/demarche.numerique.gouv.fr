# frozen_string_literal: true

RSpec.describe EditableChamp::ChampLabelContentComponent, type: :component do
  let(:form) { double(object: champ) }

  let(:champ_class) { ChampData }
  let(:champ) do
    instance_double(
      champ_class,
      formatted?: true,
      formatted_simple?: true,
      formatted_advanced?: false,
      letters_accepted?: false,
      numbers_accepted?: false,
      special_characters_accepted?: false,
      min_character_length: nil,
      max_character_length: nil,
      date?: false,
      datetime?: false,
      integer_number?: false,
      decimal_number?: false,
      textarea?: false,
      dossier_link?: false,
      carte?: false
    )
  end

  let(:component) do
    described_class.new(
      form: form,
      champ: champ,
      seen_at: nil,
      row_number: nil
    )
  end

  describe "#hints_for_champ" do
    context "when champ is not visible" do
      before { allow(champ).to receive(:visible?).and_return(false) }

      it "returns an empty array" do
        expect(component.hints_for_champ).to eq([])
      end
    end

    context "when champ has renderable hint" do
      before do
        allow(component).to receive(:hint_renderable?).and_return(true)
        allow(component).to receive(:hint).and_return("Un hint test")
      end

      it 'returns hint without date-input-hint controller for non-date champ' do
        expect(component.hints_for_champ).to eq([{ text: "Un hint test", controller: nil }])
      end

      context "when champ is a date" do
        before { allow(champ).to receive(:date?).and_return(true) }

        it 'returns hint with date-input-hint controller' do
          expect(component.hints_for_champ).to eq([{ text: "Un hint test", controller: "date-input-hint" }])
        end
      end

      context "when champ is a datetime" do
        before { allow(champ).to receive(:datetime?).and_return(true) }

        it 'returns hint with date-input-hint controller' do
          expect(component.hints_for_champ).to eq([{ text: "Un hint test", controller: "date-input-hint" }])
        end
      end
    end

    context "when champ is formatted simple" do
      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(true)
        allow(champ).to receive(:formatted_simple?).and_return(true)
        allow(champ).to receive(:formatted_advanced?).and_return(false)
      end

      context "with no constraints" do
        it "returns no hints" do
          expect(component.hints_for_champ).to eq([])
        end
      end

      context "with allowed letters" do
        before { allow(champ).to receive(:letters_accepted?).and_return(true) }

        it "returns a character hint (without controller)" do
          expect(component.hints_for_champ).to eq([{ text: "Le champ ne peut contenir que des lettres.", controller: nil }])
        end
      end

      context "with letters and numbers allowed" do
        before do
          allow(champ).to receive(:letters_accepted?).and_return(true)
          allow(champ).to receive(:numbers_accepted?).and_return(true)
        end

        it "returns a combined character hint (without controller)" do
          expect(component.hints_for_champ).to eq([{ text: "Le champ peut contenir des lettres et des chiffres.", controller: nil }])
        end
      end

      context "with min and max length" do
        before do
          allow(champ).to receive(:min_character_length).and_return(5)
          allow(champ).to receive(:max_character_length).and_return(10)
        end

        it "returns a range hint (without controller)" do
          expect(component.hints_for_champ).to eq([{ text: "Vous devez renseigner entre 5 et 10 caractères.", controller: nil }])
        end
      end

      context "with the same min and max length" do
        before do
          allow(champ).to receive(:min_character_length).and_return(5)
          allow(champ).to receive(:max_character_length).and_return(5)
        end

        it "returns a range hint (without controller)" do
          expect(component.hints_for_champ).to eq([{ text: "Vous devez renseigner exactement 5 caractères.", controller: nil }])
        end
      end

      context "with letters allowed and min length" do
        before do
          allow(champ).to receive(:letters_accepted?).and_return(true)
          allow(champ).to receive(:min_character_length).and_return(5)
        end

        it "returns both hints" do
          expect(component.hints_for_champ).to eq([
            { text: "Le champ ne peut contenir que des lettres.", controller: nil },
            { text: "Vous devez renseigner au moins 5 caractères.", controller: nil },
          ])
        end
      end
    end

    context "when champ is formatted advanced" do
      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(true)
        allow(champ).to receive(:formatted_simple?).and_return(false)
        allow(champ).to receive(:formatted_advanced?).and_return(true)
      end

      it "returns no hints" do
        expect(component.hints_for_champ).to eq([])
      end
    end

    context "when champ is not formatted" do
      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(false)
      end

      it "returns no hints" do
        expect(component.hints_for_champ).to eq([])
      end
    end

    context "when champ is a carte" do
      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(false)
        allow(champ).to receive(:carte?).and_return(true)
      end

      it "links to the tutorial in a new tab" do
        expect(component.hints_for_champ.map { it[:text] }).to eq([
          'Besoin d’aide ? <a title="consulter les tutoriels video — Nouvel onglet" target="_blank" rel="noopener external" href="https://doc.demarches-simplifiees.fr/pour-aller-plus-loin/cartographie">consulter les tutoriels video</a>',
        ])
      end
    end

    context "when champ is textarea without limit" do
      let(:champ_class) { Champs::TextareaChamp }

      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(false)
        allow(champ).to receive(:textarea?).and_return(true)
        allow(champ).to receive(:character_limit_base).and_return(nil)
      end

      it "returns no hints" do
        expect(component.hints_for_champ).to eq([])
      end
    end

    context "when champ is textarea with limit" do
      let(:champ_class) { Champs::TextareaChamp }

      before do
        allow(champ).to receive(:visible?).and_return(true)
        allow(champ).to receive(:formatted?).and_return(false)
        allow(champ).to receive(:textarea?).and_return(true)
        allow(champ).to receive(:character_limit_base).and_return(400)
      end

      it "returns hint" do
        expect(component.hints_for_champ).to eq([
          { text: "La taille maximale conseillée est de 400 caractères.", controller: nil },
        ])
      end
    end
  end

  describe "rendering the modification date" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: "Texte" }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.root_champs_public.first }
    let(:value_updated_at) { 3.days.ago.change(usec: 0) }
    let(:seen_at) { 1.day.ago }
    let(:component) { described_class.new(form:, champ:, seen_at:) }

    subject { render_inline(component) }

    before { champ.update_columns(updated_at: 1.hour.ago, value_updated_at:) }

    it "dates the last user change, not the Rails timestamp, and does not highlight it once seen" do
      expect(subject).to have_css(".updated-at", text: "modifié le #{I18n.l(value_updated_at)}")
      expect(subject).not_to have_css(".updated-at.highlighted")
    end

    context "when the champ was rebased after the last user change, then bumped by machinery" do
      let(:seen_at) { nil }

      before do
        champ.update_columns(rebased_at: 2.days.ago)
        allow(component).to receive(:current_user).and_return(dossier.user)
      end

      it "still asks the usager to check the content" do
        expect(subject).to have_text("champ actualisé par l’administration")
      end
    end
  end

  describe "#default_hint" do
    before_all { seed "cases/champs" }

    # `default_hint` feeds a slot, so it runs outside of any render.
    let(:champ) { dossiers.tous_champs.champ_data.find(&:rnf?) }

    it "resolves the _html hint without a view context, and marks it html_safe" do
      hint = component.default_hint

      expect(hint).to be_html_safe
      expect(hint).to include("<span aria-hidden='true'>075-FDD-00003-01</span>")
    end
  end
end
