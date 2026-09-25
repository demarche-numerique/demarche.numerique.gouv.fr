# frozen_string_literal: true

RSpec.describe Procedure::Card::InstructeursComponent, type: :component do
  subject { render_inline(described_class.new(procedure:)) }

  context 'without instructeur' do
    let(:procedure) { create(:procedure) }

    it do
      is_expected.to have_css('a#groupe-instructeurs')
      is_expected.to have_css('p.fr-badge.fr-badge--warning', text: 'À faire')
      is_expected.to have_css('p.fr-tag', text: '0')
      is_expected.to have_css('h4', exact_text: 'Instructeurs')
    end
  end

  context 'with an instructeur' do
    let(:procedure) { create(:procedure, :with_instructeur) }

    it do
      is_expected.to have_css('p.fr-badge.fr-badge--success', text: 'Validé')
      is_expected.to have_css('p.fr-tag', text: '1')
      is_expected.to have_css('h4', exact_text: 'Instructeur')
    end
  end

  context 'with routing and a groupe without routing rule' do
    let(:procedure) { create(:procedure, :with_instructeur, :routee, routing_enabled: true) }

    it 'counts the groupes and asks to configure them' do
      is_expected.to have_css('p.fr-badge.fr-badge--warning', text: 'À faire')
      is_expected.to have_css('p.fr-tag', text: '2')
      is_expected.to have_css('h4', exact_text: 'Groupe Instructeurs')
    end
  end
end
