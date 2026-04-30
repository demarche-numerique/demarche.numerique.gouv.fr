# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Procedure::Card::AiComponent, type: :component do
  let(:procedure) { create(:procedure, :published) }
  let(:draft_revision) { procedure.draft_revision }
  include Rails.application.routes.url_helpers
  subject { described_class.new(procedure:) }

  describe '#render?' do
    context 'when LLM feature is enabled' do
      before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }
      it 'returns true' do
        expect(subject.render?).to be true
      end
    end

    context 'when LLM feature is disabled' do
      it 'returns false' do
        expect(subject.render?).to be false
      end
    end
  end

  describe '#any_tunnel_finished?' do
    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }
    let(:schema_hash) { Digest::SHA256.hexdigest(draft_revision.schema_to_llm.to_json) }

    context 'when cleaner rule is accepted' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: draft_revision,
          rule: LLM::Rule::SEQUENCE.last,
          state: 'accepted',
          schema_hash: schema_hash)
      end

      it 'returns true' do
        expect(subject.any_tunnel_finished?).to be true
      end
    end

    context 'when cleaner rule is skipped' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: draft_revision,
          rule: LLM::Rule::SEQUENCE.last,
          state: 'skipped',
          schema_hash: schema_hash)
      end

      it 'returns true' do
        expect(subject.any_tunnel_finished?).to be true
      end
    end

    context 'when no cleaner rule exists' do
      it 'returns false' do
        expect(subject.any_tunnel_finished?).to be false
      end
    end

    context 'when cleaner rule is not finished' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: draft_revision,
          rule: LLM::Rule::SEQUENCE.last,
          state: 'completed',
          schema_hash: schema_hash)
      end

      it 'returns false' do
        expect(subject.any_tunnel_finished?).to be false
      end
    end
  end

  describe 'rendered component' do
    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }

    context 'with suggestions' do
      let(:schema_hash) { Digest::SHA256.hexdigest(draft_revision.schema_to_llm.to_json) }
      before do
        create(:llm_rule_suggestion,
               procedure_revision: draft_revision,
               schema_hash:,
               state:,
               rule:)
      end

      context 'when last rule is not started' do
        let(:rule) { 'improve_label' }
        let(:state) { :accepted }

        it do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end

      context 'when last rule is not finished' do
        let(:rule) { LLM::Rule::SEQUENCE.last }
        let(:state) { :completed }
        let!(:first_rule) do
          create(:llm_rule_suggestion,
               procedure_revision: draft_revision,
               schema_hash:,
               state: 'accepted',
               rule: 'improve_types',
               created_at: 1.day.ago)
        end

        it do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end

      context 'when last rule is done' do
        let(:rule) { LLM::Rule::SEQUENCE.last }
        let(:state) { :accepted }

        it do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--success', text: 'Amélioré')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end

      context 'when schema changed' do
        let(:rule) { 'improve_structure' }
        let(:state) { :accepted }
        let(:schema_hash) { "something-else" }

        it do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
        end
      end

      context 'when last rule is failed' do
        let(:rule) { 'improve_types' }
        let(:state) { :failed }

        it 'shows À faire badge and links to new_simplify (failed not considered finished)' do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end

      context 'when last rule is running' do
        let(:rule) { 'improve_label' }
        let(:state) { :running }

        it 'shows À faire badge and links to new_simplify (running not considered finished)' do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end

      context 'when last rule is queued' do
        let(:rule) { LLM::Rule::SEQUENCE.last }
        let(:state) { :queued }

        it 'shows À faire badge and links to new_simplify (queued not considered finished)' do
          render_inline(subject)
          expect(page).to have_css('.fr-badge--warning', text: 'À faire')
          expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
        end
      end
    end

    context 'without suggestions' do
      before { render_inline(subject) }
      it 'shows À faire badge' do
        expect(page).to have_css('.fr-badge--warning', text: 'À faire')
        expect(page.all("a").map { it['href'] }).to include(new_simplify_admin_procedure_types_de_champ_path(procedure))
      end
    end
  end
end
