# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261014ConvertNumberChampsTask do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :integer_number }, { type: :text }]) }
    let(:type_de_champ) { procedure.published_revision.public_root_type_de_champs.first }
    let(:other_type_de_champ) { procedure.published_revision.public_root_type_de_champs.second }
    let(:values) { ['42'] }
    let(:champs) do
      values.map do |value|
        dossier = create(:dossier, :en_construction, procedure:)
        dossier.champ_data.find_by(stable_id: type_de_champ.stable_id).tap { ChampData.where(id: it.id).update_all(type: 'Champs::NumberChamp', value:) }
      end
    end
    let(:other_champ) { ChampData.find_by(dossier_id: champs.first.dossier_id, stable_id: other_type_de_champ.stable_id) }

    before do
      champs
      type_de_champ.update_columns(type_champ: 'number')
    end

    def raw_type_champ(id)
      TypeDeChamp.connection.select_value("SELECT type_champ FROM types_de_champ WHERE id = #{id}")
    end

    def raw_champs
      ChampData.where(id: champs.map(&:id)).order(:id).pluck(:type, :value)
    end

    describe "#collection" do
      it "returns the stable ids of the number types de champ" do
        expect(described_class.new.collection).to include(type_de_champ.stable_id)
        expect(described_class.new.collection).not_to include(other_type_de_champ.stable_id)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(type_de_champ.stable_id) }

      it "converts the type de champ to integer_number" do
        expect { process }.to change { raw_type_champ(type_de_champ.id) }.from('number').to('integer_number')
      end

      it "converts every copy of the type de champ sharing the stable id" do
        copy = type_de_champ.dup
        copy.save!
        copy.update_columns(stable_id: type_de_champ.stable_id, type_champ: 'number')

        expect { process }.to change { raw_type_champ(copy.id) }.from('number').to('integer_number')
      end

      it "converts the champ to integer_number, keeping its value" do
        expect { process }.to change { raw_champs }
          .from([['Champs::NumberChamp', '42']])
          .to([['Champs::IntegerNumberChamp', '42']])
      end

      it "leaves the other types de champ and champs untouched" do
        expect { process }.not_to change { [raw_type_champ(other_type_de_champ.id), ChampData.where(id: other_champ.id).pick(:type, :value)] }
      end

      context "when the values are integers once cleaned" do
        let(:values) { ['42', '1 000', "1 000", '150 €', '50%', 'environ 30'] }

        it "converts to integer_number, cleans the values and keeps the free text" do
          process

          expect(raw_type_champ(type_de_champ.id)).to eq('integer_number')
          expect(raw_champs).to eq([
            ['Champs::IntegerNumberChamp', '42'],
            ['Champs::IntegerNumberChamp', '1000'],
            ['Champs::IntegerNumberChamp', '1000'],
            ['Champs::IntegerNumberChamp', '150'],
            ['Champs::IntegerNumberChamp', '50'],
            ['Champs::IntegerNumberChamp', 'environ 30'],
          ])
        end
      end

      context "when a value is a decimal" do
        let(:values) { ['42', '1 000', '12,5', '12,5 %', 'environ 30'] }

        it "converts to decimal_number, cleans the values and keeps the free text" do
          process

          expect(raw_type_champ(type_de_champ.id)).to eq('decimal_number')
          expect(raw_champs).to eq([
            ['Champs::DecimalNumberChamp', '42'],
            ['Champs::DecimalNumberChamp', '1000'],
            ['Champs::DecimalNumberChamp', '12.5'],
            ['Champs::DecimalNumberChamp', '12.5'],
            ['Champs::DecimalNumberChamp', 'environ 30'],
          ])
        end
      end
    end
  end
end
