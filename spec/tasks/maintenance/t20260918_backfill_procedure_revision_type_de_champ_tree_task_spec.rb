# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260918BackfillProcedureRevisionTypeDeChampTreeTask do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, level: 1 },
        { type: :repetition, children: [{}, {}] },
      ], private_type_de_champs: [{}])
    end
    let(:revision) { procedure.published_revision }

    subject(:process) { described_class.new.process(procedure) }

    it "enregistre l’arbre des révisions publiées" do
      expect { process }.to change { revision.reload.read_attribute(:type_de_champ_tree) }
        .from(nil).to(TypeDeChampTree.from_coordinates(revision.revision_type_de_champs))
    end

    it "enregistre l’arbre des révisions d’une démarche supprimée" do
      procedure.discard!

      expect { process }.to change { revision.reload.read_attribute(:type_de_champ_tree) }.from(nil)
    end

    it "ne touche pas à updated_at" do
      expect { process }.not_to change { revision.reload.updated_at }
    end

    it "enregistre l’arbre du brouillon" do
      draft_revision = procedure.draft_revision

      expect { process }.to change { draft_revision.reload.read_attribute(:type_de_champ_tree) }
        .from(nil).to(TypeDeChampTree.from_coordinates(draft_revision.revision_type_de_champs))
    end

    # la démarche est chargée avec son lot, et peut être modifiée avant d’être traitée
    it "laisse l’arbre qu’une édition du brouillon a enregistré depuis le chargement de la démarche" do
      stale_procedure = Procedure.find(procedure.id)
      procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'nouveau')

      expect { described_class.new.process(stale_procedure) }
        .not_to change { procedure.draft_revision.reload.read_attribute(:type_de_champ_tree) }
    end

    it "ne réécrit pas un arbre déjà enregistré" do
      stored = TypeDeChampTree.new
      revision.update_columns(type_de_champ_tree: stored)

      expect { process }.not_to change { revision.reload.read_attribute(:type_de_champ_tree) }.from(stored)
    end

    context "avec l’enfant d’un type de champ qui n’est plus une répétition" do
      before do
        revision.public_root_type_de_champs.find(&:repetition?).update_columns(type_champ: 'text')
        revision.reload
      end

      it "l’écarte de l’arbre et le signale" do
        allow(Rails.logger).to receive(:warn)

        process

        header_section, = revision.reload.type_de_champ_tree.public_children
        expect(header_section.children.map(&:children)).to eq([[]])
        expect(Rails.logger).to have_received(:warn).with(/revision #{revision.id} .* leaves 2 coordinates/)
      end
    end

    # process seul ne voit pas ce que le job attend de la tâche (Task#count…)
    it "s’exécute par le job" do
      revision
      run = MaintenanceTasks::Run.create!(task_name: described_class.name)

      MaintenanceTasks::TaskJob.perform_now(run)

      expect(run.reload).to have_attributes(status: "succeeded", error_class: nil)
      expect(revision.reload.read_attribute(:type_de_champ_tree)).to be_present
    end

    describe "#collection" do
      it "retient les démarches supprimées" do
        procedure.discard!

        expect(described_class.new.collection).to include(procedure)
      end
    end
  end
end
