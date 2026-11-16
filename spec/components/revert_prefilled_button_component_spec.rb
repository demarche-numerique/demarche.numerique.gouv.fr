# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditableChamp::RevertPrefilledButtonComponent, type: :component do
  let(:public_type_de_champs) { [{ type: :text }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }

  subject { render_inline(described_class.new(champ:)) }

  context 'when champ is prefilled and modified' do
    before do
      champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' })
    end

    it 'renders the revert button' do
      expect(subject).to have_button("Remplir à nouveau automatiquement")
    end
  end

  context 'when champ is a child of a repetition' do
    let(:public_type_de_champs) { [{ type: :repetition, mandatory: false, children: [{ type: :text }] }] }
    let(:champ) do
      repetition = dossier.revision.public_root_type_de_champs.first
      row_id = dossier.repetition_add_row(repetition, updated_by: 'test')
      dossier.champ_for_update(dossier.revision.type_de_champ(repetition.stable_id).flat_children.first, row_id:, updated_by: 'test')
    end

    before do
      champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' })
    end

    it 'targets the champ of its row' do
      expect(subject).to have_css("button[formaction$='/champs/#{champ.public_id}/revert_prefill']")
    end
  end

  context 'when champ is prefilled but not modified' do
    before do
      champ.update!(prefilled: true, value: 'original', prefilled_original_value: { 'value' => 'original' })
    end

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'when champ is not prefilled' do
    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'when champ is private (annotation)' do
    let(:private_type_de_champs) { [{ type: :text }] }
    let(:procedure) { create(:procedure, private_type_de_champs:) }
    let(:champ) { dossier.champ_data.find(&:private?) }

    before do
      champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' })
    end

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'when champ is on instructeur buffer stream' do
    before do
      champ.update!(prefilled: true, value: 'modified', prefilled_original_value: { 'value' => 'original' }, stream: Dossier::INSTRUCTEUR_BUFFER_STREAM)
    end

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end
end
