# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20251208backfillUniqueAndValidRoutingRuleInGroupeInstructeursTask do
    include Logic

    let(:procedure) { create(:procedure, routing_enabled: true, administrateur: admin) }
    let(:admin) { administrateurs(:default_admin) }
    let(:stable_id) { procedure.published_revision.types_de_champ_public.last.stable_id }

    before do
      procedure.draft_revision.add_type_de_champ(
        type_champ: :drop_down_list,
        libelle: 'Ville',
        drop_down_options: ['Paris', 'Lyon', 'Marseille']
      )
      procedure.publish_revision!(admin)
    end

    describe "#collection" do
      let!(:not_routed_procedure) { create(:procedure, routing_enabled: false) }

      it "returns only procedures with routing enabled" do
        collection = described_class.new.collection

        expect(collection).to include(procedure)
        expect(collection).not_to include(not_routed_procedure)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      context "when procedure has groups with valid and unique routing rules" do
        let!(:gi1) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe 1',
                 routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
        end
        let!(:gi2) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe 2',
                 routing_rule: ds_eq(champ_value(stable_id), constant('Lyon')))
        end

        it "sets unique_routing_rule to true for unique routing rule" do
          expect { process }.to change { gi1.reload.unique_routing_rule }.from(false).to(true)
            .and change { gi2.reload.unique_routing_rule }.from(false).to(true)
        end

        it "sets valid_routing_rule to true for valid routing rule" do
          expect { process }.to change { gi1.reload.valid_routing_rule }.from(false).to(true)
            .and change { gi2.reload.valid_routing_rule }.from(false).to(true)
        end
      end

      context "when procedure has a group with invalid routing rule" do
        let!(:gi1) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe Invalid',
                 routing_rule: ds_eq(champ_value(999), constant('Invalid')))
        end

        it "maintains valid_routing_rule as false" do
          expect { process }.not_to change { gi1.reload.valid_routing_rule }
        end

        it "sets unique_routing_rule to true" do
          expect { process }.to change { gi1.reload.unique_routing_rule }.from(false).to(true)
        end
      end

      context "when procedure has duplicate routing rules" do
        let!(:gi1) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe 1',
                 routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
        end
        let!(:gi2) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe 2',
                 routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
        end

        it "maintains unique_routing_rule to false for duplicate routing rules" do
          expect { process }.not_to change { gi1.reload.unique_routing_rule }
          expect { process }.not_to change { gi2.reload.unique_routing_rule }
        end

        it "still validates the rules correctly" do
          expect { process }.to change { gi1.reload.valid_routing_rule }.from(false).to(true)
            .and change { gi2.reload.valid_routing_rule }.from(false).to(true)
        end
      end

      context "when procedure has a nil routing rule" do
        let!(:gi1) do
          create(:groupe_instructeur,
                 procedure: procedure,
                 label: 'Groupe Sans Règle',
                 routing_rule: nil)
        end

        it "maintains valid_routing_rule as false " do
          expect { process }.not_to change { gi1.reload.valid_routing_rule }
        end

        it "maintains unique_routing_rule as false" do
          process
          expect(gi1.reload.unique_routing_rule).to be_falsey
        end
      end
    end
  end
end
