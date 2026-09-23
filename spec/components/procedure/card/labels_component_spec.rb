# frozen_string_literal: true

RSpec.describe Procedure::Card::LabelsComponent, type: :component do
  subject { render_inline(described_class.new(procedure:)) }

  context 'without label' do
    let(:procedure) { create(:procedure) }

    it 'shows no counter' do
      is_expected.to have_css('p.fr-badge.fr-badge--info', text: 'À configurer')
      is_expected.to have_no_css('.fr-tag')
    end
  end

  context 'with labels' do
    let(:procedure) { create(:procedure, :with_labels) }

    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: 'Configuré')
      is_expected.to have_css('p.fr-tag', text: procedure.labels.size.to_s)
    end
  end
end
