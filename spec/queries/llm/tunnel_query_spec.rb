# frozen_string_literal: true

describe LLM::TunnelQuery do
  let(:procedure) { create(:procedure) }
  let(:revision) { procedure.draft_revision }
  let(:tunnel_id) { 'abc123' }
  let(:query) { described_class.new(procedure_revision: revision, tunnel_id:) }

  describe '.any_finished?' do
    context 'when at least one tunnel has finished last step' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: 'aabbcc',
          rule: 'cleaner',
          state: :accepted)
      end

      it { expect(described_class.any_finished?(procedure_revision_id: revision.id)).to be true }
    end

    context 'when no tunnel has finished' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: 'ddeeff',
          rule: 'improve_label',
          state: :accepted)
      end

      it { expect(described_class.any_finished?(procedure_revision_id: revision.id)).to be false }
    end

    context 'when no suggestions exist' do
      it { expect(described_class.any_finished?(procedure_revision_id: revision.id)).to be false }
    end
  end

  describe '.find_active_tunnel_id_for' do
    context 'when there is an active tunnel' do
      let(:active_tunnel_id) { 'aabbcc' }
      let(:finished_tunnel_id) { 'ddeeff' }

      before do
        # Finished tunnel (last step accepted)
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: finished_tunnel_id,
          rule: 'cleaner',
          state: :accepted)

        # Active tunnel (only first step completed)
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: active_tunnel_id,
          rule: 'improve_label',
          state: :accepted)
      end

      it 'returns the active tunnel_id' do
        expect(described_class.find_active_tunnel_id_for(revision)).to eq(active_tunnel_id)
      end
    end

    context 'when there are multiple active tunnels' do
      let(:active_tunnel_1) { 'aabbcc' }
      let(:active_tunnel_2) { 'ddeeff' }

      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: active_tunnel_1,
          rule: 'improve_label',
          state: :accepted)
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: active_tunnel_2,
          rule: 'improve_structure',
          state: :accepted)
      end

      it 'returns one of the active tunnel_ids' do
        result = described_class.find_active_tunnel_id_for(revision)
        expect([active_tunnel_1, active_tunnel_2]).to include(result)
      end
    end

    context 'when all tunnels are finished' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id: 'aabbcc',
          rule: 'cleaner',
          state: :accepted)
      end

      it 'returns nil' do
        expect(described_class.find_active_tunnel_id_for(revision)).to be_nil
      end
    end

    context 'when no tunnels exist' do
      it 'returns nil' do
        expect(described_class.find_active_tunnel_id_for(revision)).to be_nil
      end
    end
  end

  describe '#finished?' do
    context 'when last step is accepted' do
      before do
        # Create first step (required by finished?)
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'improve_label',
          state: :accepted)
        # Create last step
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'cleaner',
          state: :accepted)
      end

      it { expect(query.finished?).to be true }
    end

    context 'when last step is skipped' do
      before do
        # Create first step (required by finished?)
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'improve_label',
          state: :accepted)
        # Create last step
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'cleaner',
          state: :skipped)
      end

      it { expect(query.finished?).to be true }
    end

    context 'when last step is pending' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'cleaner',
          state: :pending)
      end

      it { expect(query.finished?).to be false }
    end

    context 'when no last step' do
      it { expect(query.finished?).to be false }
    end
  end

  describe '#last_completed_step' do
    it 'returns the most recent completed step' do
      older = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        state: :accepted,
        created_at: 2.days.ago)
      newer = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_structure',
        state: :completed,
        created_at: 1.day.ago)

      expect(query.last_completed_step).to eq(newer)
    end
  end

  describe '#find_for_rule' do
    it 'returns suggestion for rule with current schema' do
      suggestion = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))

      expect(query.find_for_rule(rule: 'improve_label')).to eq(suggestion)
    end

    it 'returns nil when schema has changed' do
      create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        schema_hash: 'old_schema_hash')

      expect(query.find_for_rule(rule: 'improve_label')).to be_nil
    end
  end

  describe '#build_for_rule' do
    it 'builds new suggestion with current schema hash' do
      built = query.build_for_rule(rule: 'improve_label')

      expect(built.tunnel_id).to eq(tunnel_id)
      expect(built.rule).to eq('improve_label')
      expect(built.schema_hash).to eq(Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))
      expect(built).to be_new_record
    end
  end

  describe '#find_completed' do
    it 'returns completed suggestion by id with correct schema' do
      suggestion = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        state: :completed,
        schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))

      expect(query.find_completed(id: suggestion.id, rule: 'improve_label')).to eq(suggestion)
    end

    it 'returns nil when suggestion has wrong schema' do
      suggestion = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        state: :completed,
        schema_hash: 'old_schema_hash')

      expect(query.find_completed(id: suggestion.id, rule: 'improve_label')).to be_nil
    end

    it 'returns nil when suggestion is not completed' do
      suggestion = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_label',
        state: :pending,
        schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))

      expect(query.find_completed(id: suggestion.id, rule: 'improve_label')).to be_nil
    end
  end

  describe '#in_progress?' do
    context 'when search is queued' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'improve_label',
          state: :queued,
          schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))
      end

      it { expect(query.in_progress?(rule: 'improve_label')).to be true }
    end

    context 'when search is running' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'improve_label',
          state: :running,
          schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))
      end

      it { expect(query.in_progress?(rule: 'improve_label')).to be true }
    end

    context 'when no search is running' do
      it { expect(query.in_progress?(rule: 'improve_label')).to be false }
    end

    context 'when search is completed' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: 'improve_label',
          state: :completed,
          schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))
      end

      it { expect(query.in_progress?(rule: 'improve_label')).to be false }
    end
  end

  describe '#find_or_create_next_step!' do
    it 'creates next step suggestion with current schema' do
      expect {
        query.find_or_create_next_step!(current_rule: 'improve_label')
      }.to change { revision.llm_rule_suggestions.count }.by(1)

      next_suggestion = revision.llm_rule_suggestions.last
      expect(next_suggestion.tunnel_id).to eq(tunnel_id)
      expect(next_suggestion.rule).to eq('improve_structure')
      expect(next_suggestion.state).to eq('pending')
      expect(next_suggestion.schema_hash).to eq(Digest::SHA256.hexdigest(revision.reload.schema_to_llm.to_json))
    end

    it 'returns existing next step if already created' do
      existing = create(:llm_rule_suggestion,
        procedure_revision: revision,
        tunnel_id:,
        rule: 'improve_structure',
        schema_hash: Digest::SHA256.hexdigest(revision.schema_to_llm.to_json))

      expect {
        result = query.find_or_create_next_step!(current_rule: 'improve_label')
        expect(result.id).to eq(existing.id)
      }.not_to change { revision.llm_rule_suggestions.count }
    end

    it 'returns nil when on last rule' do
      expect(query.find_or_create_next_step!(current_rule: 'cleaner')).to be_nil
    end

    it 'uses reloaded schema hash after modifications' do
      # Simulate schema modification by adding a field
      revision.add_type_de_champ(type_champ: :text, libelle: 'New field')

      next_suggestion = query.find_or_create_next_step!(current_rule: 'improve_label')

      # Should use the NEW schema hash (after reload)
      expect(next_suggestion.schema_hash).to eq(Digest::SHA256.hexdigest(revision.reload.schema_to_llm.to_json))
    end
  end
end
