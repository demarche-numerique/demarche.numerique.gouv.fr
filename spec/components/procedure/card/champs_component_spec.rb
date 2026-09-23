# frozen_string_literal: true

describe Procedure::Card::ChampsComponent, type: :component do
  describe 'render' do
    let(:procedure) { create(:procedure, private_type_de_champs:, public_type_de_champs:) }
    let(:private_type_de_champs) { [] }
    let(:public_type_de_champs) { [] }
    before { procedure.validate(:publication) }
    subject { render_inline(described_class.new(procedure: procedure)) }

    context 'when no errors' do
      it 'does not render' do
        expect(subject).to have_selector('.fr-badge--warning', text: 'À faire')
      end
    end

    context 'when errors on public_type_de_champs' do
      let(:public_type_de_champs) { [{ type: :repetition, children: [] }] }
      it 'does not render' do
        expect(subject).to have_selector('.fr-badge--error', text: 'À modifier')
      end
    end

    context 'when errors on private_type_de_champs' do
      let(:private_type_de_champs) { [{ type: :repetition, children: [] }] }

      it 'render the template' do
        expect(subject).to have_selector('.fr-badge--warning', text: 'À faire')
      end
    end
  end
end
