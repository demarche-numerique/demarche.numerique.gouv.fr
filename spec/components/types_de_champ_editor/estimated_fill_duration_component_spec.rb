# frozen_string_literal: true

describe TypesDeChampEditor::EstimatedFillDurationComponent, type: :component do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:is_annotation) { false }

  subject(:rendered) { render_inline(described_class.new(revision: procedure.draft_revision, is_annotation:)) }

  context 'with conditions' do
    let(:public_type_de_champs) do
      [
        { type: :yes_no, mandatory: true, description: nil, stable_id: 1 },
        { type: :piece_justificative, mandatory: true, description: nil, condition: ds_eq(champ_value(1), constant(true)) },
      ]
    end

    it { expect(rendered).to have_text('Durée de remplissage estimée').and have_text(/1 à 3.min/) }

    context 'for annotations' do
      let(:is_annotation) { true }

      it { expect(rendered).to have_no_text('Durée de remplissage estimée') }
    end
  end

  context 'without champs' do
    let(:public_type_de_champs) { [] }

    it { expect(rendered).to have_no_text('Durée de remplissage estimée') }
  end
end
