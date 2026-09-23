# frozen_string_literal: true

describe Procedure::Card::ChorusComponent, type: :component do
  describe 'render' do
    let(:procedure) { create(:procedure) }

    subject do
      render_inline(described_class.new(procedure: procedure))
    end

    context 'feature flag not active' do
      it 'does not render' do
        subject
        expect(page).not_to have_text('Connecteur Chorus')
      end
    end
    context 'feature flag active' do
      before { Flipper.enable_actor :engagement_juridique_type_de_champ, procedure }

      it 'render the template' do
        subject
        expect(page).to have_text('Connecteur Chorus')
      end
    end
  end
end
