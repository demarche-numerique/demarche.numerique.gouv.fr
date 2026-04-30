# frozen_string_literal: true

RSpec.describe EditableChamp::ChampLabelContentComponent, type: :component do
  let(:form) { double(object: champ) }

  let(:champ_class) { Champ }
  let(:champ) do
    instance_double(
      champ_class,
      formatted?: true,
      formatted_simple?: true,
      formatted_advanced?: false,
      letters_accepted: false,
      numbers_accepted: false,
      special_characters_accepted: false,
      min_character_length: nil,
      max_character_length: nil,
      date?: false,
      datetime?: false,
      integer_number?: false,
      decimal_number?: false,
      textarea?: false,
      dossier_link?: false
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
        before { allow(champ).to receive(:letters_accepted).and_return(true) }

        it "returns a character hint (without controller)" do
          expect(component.hints_for_champ).to eq([{ text: "Le champ ne peut contenir que des lettres.", controller: nil }])
        end
      end

      context "with letters and numbers allowed" do
        before do
          allow(champ).to receive(:letters_accepted).and_return(true)
          allow(champ).to receive(:numbers_accepted).and_return(true)
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
          allow(champ).to receive(:letters_accepted).and_return(true)
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
end
