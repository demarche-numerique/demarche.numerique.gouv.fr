# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261002KeepSingleParcelleLayerOnCartesTask do
    # Past the model, which no longer saves both parcelle layers.
    def carte_with(options)
      create(:type_de_champ_carte, no_coordinate: true).tap { it.update_column(:options, options) }
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "returns the cartes holding both parcelle layers" do
        expect(collection).to include(carte_with(cadastres: '1', rpg: 'true'))
      end

      it "ignores the cartes holding one parcelle layer" do
        expect(collection).not_to include(carte_with(cadastres: '1'), carte_with(rpg: '1', znieff: '1'))
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(type_de_champ) }

      context "with both parcelle layers enabled" do
        let(:type_de_champ) { carte_with(cadastres: '1', rpg: '1', znieff: '1') }

        it "keeps cadastres, and the other layers" do
          process

          expect(type_de_champ.reload.options).to eq({ 'cadastres' => '1', 'rpg' => false, 'znieff' => '1' })
        end
      end

      context "with one of them disabled" do
        let(:type_de_champ) { carte_with(cadastres: '0', rpg: '1') }

        it "leaves the options as they are" do
          expect { process }.not_to change { type_de_champ.reload.options }
        end
      end
    end
  end
end
