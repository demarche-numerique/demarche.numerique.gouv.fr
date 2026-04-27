# frozen_string_literal: true

describe Conditions::IneligibiliteRulesComponent, type: :component do
  include Logic
  let(:procedure) { create(:procedure) }
  let(:component) { described_class.new(draft_revision: procedure.draft_revision) }

  before do
    allow_any_instance_of(described_class)
      .to receive(:feature_enabled?).with(:column_conditions).and_return(false)
  end

  describe 'render' do
    let(:ineligibilite_message) { 'ok' }
    let(:ineligibilite_enabled) { true }
    before do
      procedure.draft_revision.update(ineligibilite_rules:, ineligibilite_message:, ineligibilite_enabled:)
    end
    context 'when ineligibilite_rules are valid' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(true)) }
      it 'does not render error' do
        render_inline(component)
        expect(page).not_to have_selector('.errors-summary')
      end
    end
    context 'when ineligibilite_rules are invalid' do
      let(:ineligibilite_rules) { ds_eq(constant(true), constant(1)) }
      it 'does not render error' do
        render_inline(component)
        expect(page).to have_selector('.errors-summary')
      end
    end
  end

  describe '#pending_changes' do
    context 'when procedure is published' do
      it 'detect changes when setup changes' do
        expect(component.pending_changes?).to be_falsey

        procedure.draft_revision.ineligibilite_message = 'changed'
        expect(component.pending_changes?).to be_falsey

        procedure.reload
        procedure.draft_revision.ineligibilite_enabled = true
        expect(component.pending_changes?).to be_falsey

        procedure.reload
        procedure.draft_revision.ineligibilite_rules = {}
        expect(component.pending_changes?).to be_falsey
      end
    end

    context 'when procedure is published' do
      let(:procedure) { create(:procedure, :published) }
      it 'detect changes when setup changes' do
        expect(component.pending_changes?).to be_falsey

        procedure.draft_revision.ineligibilite_message = 'changed'
        expect(component.pending_changes?).to be_truthy

        procedure.reload
        procedure.draft_revision.ineligibilite_enabled = true
        expect(component.pending_changes?).to be_truthy

        procedure.reload
        procedure.draft_revision.ineligibilite_rules = {}
        expect(component.pending_changes?).to be_truthy
      end
    end
  end
end
