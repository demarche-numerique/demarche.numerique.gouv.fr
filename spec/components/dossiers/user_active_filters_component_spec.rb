# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::UserActiveFiltersComponent, type: :component do
  let(:tags) do
    [
      { group: :procedure_id, value: '42', label: 'Demande de subvention' },
      { group: :state, value: 'depose', label: 'Déposé' },
    ]
  end

  subject do
    render_inline(described_class.new(tags: tags, current_filter_params: { state: ['depose'], procedure_id: '42' }))
  end

  it 'renders one chip per tag' do
    expect(subject.css('.user-active-filters__chip').size).to eq(2)
  end

  it 'renders the reset link' do
    expect(subject.to_html).to include('Réinitialiser les filtres')
  end

  context 'with empty tags' do
    let(:tags) { [] }
    it 'renders nothing' do
      expect(subject.to_html.strip).to be_empty
    end
  end
end
