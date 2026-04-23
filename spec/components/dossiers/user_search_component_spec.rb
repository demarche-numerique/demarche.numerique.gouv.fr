# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::UserSearchComponent, type: :component do
  let(:search_terms) { nil }
  let(:active_filter_count) { 0 }
  let(:filter_params) { {} }

  subject do
    render_inline(described_class.new(search_terms: search_terms, active_filter_count: active_filter_count, filter_params: filter_params))
  end

  it 'renders the search input' do
    expect(subject.css('input[name=search]')).to be_present
  end

  it 'renders the filter open button without count when no filter active' do
    expect(subject.to_html).to match(/Filtrer les dossiers(?!\s*\()/)
  end

  context 'with active filters' do
    let(:active_filter_count) { 3 }

    it 'renders the filter open button with count' do
      expect(subject.to_html).to include('Filtrer les dossiers (3)')
    end
  end

  context 'with search terms' do
    let(:search_terms) { 'Dupont' }

    it 'pre-fills the input' do
      expect(subject.css('input[name=search]').first['value']).to eq('Dupont')
    end
  end
end
