# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260310BackfillLLMRuleSuggestionTunnelIdTask do
    let(:procedure) { create(:procedure) }
    let(:revision) { procedure.draft_revision }

    describe "#process" do
      it "assigns tunnel_id to suggestions starting with improve_label" do
        # Create suggestions without tunnel_id in chronological order
        label1 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_label',
          tunnel_id: nil,
          created_at: 4.days.ago)
        label1.save(validate: false)

        structure1 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_structure',
          tunnel_id: nil,
          created_at: 3.days.ago)
        structure1.save(validate: false)

        types1 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_types',
          tunnel_id: nil,
          created_at: 2.days.ago)
        types1.save(validate: false)

        # New tunnel starts with improve_label
        label2 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_label',
          tunnel_id: nil,
          created_at: 1.day.ago)
        label2.save(validate: false)

        structure2 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_structure',
          tunnel_id: nil,
          created_at: 1.hour.ago)
        structure2.save(validate: false)

        described_class.new.process(revision)

        # Reload to get updated values
        label1.reload
        structure1.reload
        types1.reload
        label2.reload
        structure2.reload

        # First improve_label starts first tunnel
        expect(label1.tunnel_id).to be_present
        expect(label1.tunnel_id).to match(/\A[a-f0-9]{6}\z/)

        # Subsequent suggestions in same tunnel
        expect(structure1.tunnel_id).to eq(label1.tunnel_id)
        expect(types1.tunnel_id).to eq(label1.tunnel_id)

        # Second improve_label starts NEW tunnel
        expect(label2.tunnel_id).to be_present
        expect(label2.tunnel_id).to match(/\A[a-f0-9]{6}\z/)
        expect(label2.tunnel_id).not_to eq(label1.tunnel_id)

        # structure2 follows label2
        expect(structure2.tunnel_id).to eq(label2.tunnel_id)
      end

      it "handles orphaned suggestions (no improve_label before them)" do
        # Suggestion without preceding improve_label
        orphan = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_types',
          tunnel_id: nil)
        orphan.save(validate: false)

        described_class.new.process(revision)

        # Should still get a tunnel_id
        expect(orphan.reload.tunnel_id).to be_present
        expect(orphan.tunnel_id).to match(/\A[a-f0-9]{6}\z/)
      end

      it "generates unique tunnel_ids" do
        # Create multiple tunnels
        label1 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_label',
          tunnel_id: nil,
          created_at: 2.days.ago)
        label1.save(validate: false)

        label2 = build(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_label',
          tunnel_id: nil,
          created_at: 1.day.ago)
        label2.save(validate: false)

        described_class.new.process(revision)

        label1.reload
        label2.reload

        # Each should have different tunnel_ids
        expect(label1.tunnel_id).not_to eq(label2.tunnel_id)
      end

      it "skips suggestions that already have tunnel_id" do
        # Create suggestion with existing tunnel_id
        existing = create(:llm_rule_suggestion,
          procedure_revision: revision,
          rule: 'improve_label',
          tunnel_id: 'abc123')

        original_tunnel_id = existing.tunnel_id

        described_class.new.process(revision)

        # Should not change existing tunnel_id
        expect(existing.reload.tunnel_id).to eq(original_tunnel_id)
      end
    end

    describe "#count" do
      it "returns number of procedure_revisions with suggestions needing backfill" do
        procedure1 = create(:procedure)
        procedure2 = create(:procedure)
        procedure3 = create(:procedure)

        # procedure1 and procedure2 need backfill
        suggestion1 = build(:llm_rule_suggestion,
          procedure_revision: procedure1.draft_revision,
          tunnel_id: nil)
        suggestion1.save(validate: false)

        suggestion2 = build(:llm_rule_suggestion,
          procedure_revision: procedure2.draft_revision,
          tunnel_id: nil)
        suggestion2.save(validate: false)

        # procedure3 already has tunnel_id
        create(:llm_rule_suggestion,
          procedure_revision: procedure3.draft_revision,
          tunnel_id: 'abc123')

        expect(described_class.new.count).to eq(2)
      end

      it "returns 0 when all suggestions have tunnel_id" do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: 'abc123')

        expect(described_class.new.count).to eq(0)
      end
    end

    describe "#collection" do
      it "returns procedure_revisions with suggestions needing backfill" do
        procedure1 = create(:procedure)
        procedure2 = create(:procedure)

        suggestion1 = build(:llm_rule_suggestion,
          procedure_revision: procedure1.draft_revision,
          tunnel_id: nil)
        suggestion1.save(validate: false)

        suggestion2 = build(:llm_rule_suggestion,
          procedure_revision: procedure2.draft_revision,
          tunnel_id: nil)
        suggestion2.save(validate: false)

        collection = described_class.new.collection.to_a

        expect(collection).to contain_exactly(
          procedure1.draft_revision,
          procedure2.draft_revision
        )
      end
    end
  end
end
