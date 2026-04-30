# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260317FixProcedurePathsEndingWithTrailingSeparatorTask do
    describe "#collection" do
      subject { described_class.new.collection }

      let!(:procedure_with_hyphen) { create(:procedure) }
      let!(:procedure_with_underscore) { create(:procedure) }
      let!(:normal_procedure) { create(:procedure) }

      before do
        procedure_with_hyphen.procedure_paths.first.update_columns(path: "ma-demarche-")
        procedure_with_underscore.procedure_paths.first.update_columns(path: "ma-demarche_")
        normal_procedure.procedure_paths.first.update_columns(path: "ma-demarche")
      end

      it "returns only paths ending with a hyphen or underscore" do
        expect(subject).to contain_exactly(
          procedure_with_hyphen.procedure_paths.first,
          procedure_with_underscore.procedure_paths.first
        )
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(procedure_path) }

      context "when the path ends with a hyphen and the fixed path is available" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before { procedure_path.update_columns(path: "ma-demarche-") }

        it "adds a new canonical path without the trailing hyphen" do
          expect { process }.to change { procedure.reload.canonical_path }.from("ma-demarche-").to("ma-demarche")
        end
      end

      context "when the path ends with an underscore and the fixed path is available" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before { procedure_path.update_columns(path: "ma-demarche_") }

        it "adds a new canonical path without the trailing underscore" do
          expect { process }.to change { procedure.reload.canonical_path }.from("ma-demarche_").to("ma-demarche")
        end
      end

      context "when the path ends with multiple trailing separators" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before { procedure_path.update_columns(path: "ma-demarche--") }

        it "strips all trailing separators" do
          expect { process }.to change { procedure.reload.canonical_path }.from("ma-demarche--").to("ma-demarche")
        end
      end

      context "when the fixed path is already taken by another procedure" do
        let(:procedure) { create(:procedure) }
        let(:other_procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before do
          procedure_path.update_columns(path: "ma-demarche-")
          other_procedure.procedure_paths.first.update_columns(path: "ma-demarche")
        end

        it "does not change the canonical path" do
          expect { process }.not_to change { procedure.reload.canonical_path }
        end
      end

      context "when the procedure already has the fixed path" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before do
          # Set the existing path to the bad one, then add the fixed path as a newer entry
          procedure_path.update_columns(path: "ma-demarche-", updated_at: 1.minute.ago)
          ProcedurePath.insert!({ procedure_id: procedure.id, path: "ma-demarche", created_at: Time.current, updated_at: Time.current })
        end

        it "does not create a duplicate path" do
          expect { process }.not_to change { procedure.procedure_paths.count }
        end
      end

      context "when the fixed path would be shorter than 3 characters" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before { procedure_path.update_columns(path: "ab-") }

        it "does not change the canonical path" do
          expect { process }.not_to change { procedure.reload.canonical_path }
        end
      end

      context "when the associated procedure is discarded" do
        let(:procedure) { create(:procedure) }
        let(:procedure_path) { procedure.procedure_paths.first }

        before do
          procedure_path.update_columns(path: "orphan-path-")
          procedure.discard
          procedure_path.reload
        end

        it "does nothing" do
          expect { described_class.process(procedure_path) }.not_to change { ProcedurePath.count }
        end
      end

      context "when the procedure_path is not the canonical path" do
        let(:procedure) { create(:procedure) }
        let(:old_path) { procedure.procedure_paths.first }

        before do
          old_path.update_columns(path: "old-path-", updated_at: 1.minute.ago)
          ProcedurePath.insert!({ procedure_id: procedure.id, path: "current-path", created_at: Time.current, updated_at: Time.current })
        end

        it "does nothing" do
          expect { described_class.process(old_path) }.not_to change { procedure.procedure_paths.count }
        end
      end
    end
  end
end
