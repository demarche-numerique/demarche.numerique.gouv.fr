# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260223NormalizeDropDownOptionsAndRelatedChampsTask do
    describe "#process" do
      subject(:process) do
        task = described_class.new
        task.procedure_id = procedure.id.to_s
        task.process(type_de_champ)
      end

      context "with drop down list champs" do
        let(:procedure) do
          create(
            :procedure,
            types_de_champ_public: [
              {
                type: :drop_down_list,
                drop_down_options: ["  Foo   Bar  ", "Baz"],
              },
            ]
          )
        end
        let(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:champ) { dossier.champs.first }

        before do
          type_de_champ.update_column(:options, type_de_champ.options.merge(drop_down_options: ["  Foo   Bar  ", "Baz"]))
          champ.update_columns(value: "  Foo   Bar  ")
        end

        it "normalizes options and related champ values" do
          expect { process }
            .to change { type_de_champ.reload.drop_down_options }
            .from(["  Foo   Bar  ", "Baz"])
            .to(["Foo Bar", "Baz"])
            .and change { champ.reload.value }
            .from("  Foo   Bar  ")
            .to("Foo Bar")
        end
      end

      context "when options are already normalized" do
        let(:procedure) do
          create(
            :procedure,
            types_de_champ_public: [
              {
                type: :drop_down_list,
                drop_down_options: ["Foo Bar", "Baz"],
              },
            ]
          )
        end
        let(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let!(:champ) { dossier.champs.first }

        before do
          champ.update_columns(value: "  Foo   Bar  ")
        end

        it "normalizes related champ values" do
          expect { process }.to change { champ.reload.value }.from("  Foo   Bar  ").to("Foo Bar")
          expect(type_de_champ.reload.drop_down_options).to eq(["Foo Bar", "Baz"])
        end
      end
    end
  end
end
