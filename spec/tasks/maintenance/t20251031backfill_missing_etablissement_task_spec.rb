# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20251031backfillMissingEtablissementTask do
    describe "#process" do
      subject(:process) { task.process(element) }

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.project_champs_public.first }
      let(:element) { { "champ_id" => champ.champ_data.id.to_s } }
      let(:task) { described_class.new }
      let(:csv_content) do
        <<~CSV
          champ_id
          #{champ.champ_data.id}
        CSV
      end

      before do
        allow(task).to receive(:csv_content).and_return(csv_content)
      end

      context "when champ exists with external_id" do
        before do
          champ.update(external_id: "13002526500013")
        end

        it "resets and fetches external data with random delay" do
          expect_any_instance_of(Champs::SiretChamp).to receive(:reset_external_data!)
          expect_any_instance_of(Champs::SiretChamp).to receive(:fetch_later!) do |_, options|
            expect(options[:wait]).to be_between(0, 20).inclusive
          end
          process
        end
      end

      context "when champ does not exist" do
        let(:element) { { "champ_id" => "999999" } }

        it "does nothing" do
          expect { process }.not_to raise_error
        end
      end

      context "when champ has no external_id" do
        before do
          champ.update(external_id: nil)
        end

        it "does nothing" do
          expect { process }.not_to raise_error
        end
      end
    end
  end
end
