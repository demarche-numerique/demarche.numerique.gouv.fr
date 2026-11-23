# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260826CleanTypeDeChampOptionsTask do
    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "returns the types de champ holding an option of another type" do
        type_de_champ = create(:type_de_champ_textarea, options: { character_limit: '400', drop_down_options: ['une option'] })

        expect(collection).to include(type_de_champ)
      end

      it "returns the types de champ having options while owning none" do
        type_de_champ = create(:type_de_champ_text, options: { drop_down_options: ['une option'] })

        expect(collection).to include(type_de_champ)
      end

      it "ignores the types de champ whose options are already clean" do
        type_de_champ = create(:type_de_champ_textarea, options: { character_limit: '400' })

        expect(collection).not_to include(type_de_champ)
      end

      it "ignores the types de champ without options" do
        type_de_champ = create(:type_de_champ_textarea, options: {})

        expect(collection).not_to include(type_de_champ)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(type_de_champ) }

      context "textarea" do
        let(:type_de_champ) do
          create(:type_de_champ_textarea, options: { character_limit: '400', drop_down_options: ['une option'] })
        end

        it "keeps the character limit only" do
          process

          expect(type_de_champ.reload.options).to eq({ 'character_limit' => '400' })
        end
      end

      context "carte" do
        let(:type_de_champ) do
          create(:type_de_champ_carte, options: { cadastres: '1', character_limit: '400' })
        end

        it "keeps the layers only" do
          process

          expect(type_de_champ.reload.options).to eq({ 'cadastres' => '1' })
        end
      end

      context "type without any option" do
        let(:type_de_champ) do
          create(:type_de_champ_text, options: { drop_down_options: ['une option'] })
        end

        it "empties the options" do
          process

          expect(type_de_champ.reload.options).to eq({})
        end
      end
    end
  end
end
