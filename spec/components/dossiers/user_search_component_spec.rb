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
    expect(subject.to_html).to include('Filtrer les dossiers')
    expect(subject.css('.user-search-bar__filter-count')).to be_empty
  end

  context 'with active filters' do
    let(:active_filter_count) { 3 }

    it 'renders the filter open button with a count badge' do
      expect(subject.to_html).to include('Filtrer les dossiers')
      expect(subject.css('.user-search-bar__filter-count').text).to eq('(3)')
    end
  end

  context 'with search terms' do
    let(:search_terms) { 'Dupont' }

    it 'pre-fills the input' do
      expect(subject.css('input[name=search]').first['value']).to eq('Dupont')
    end
  end

  describe 'filter persistence in hidden fields' do
    let(:filter_params) do
      ActionController::Parameters.new(
        procedure_id: '42',
        state: ['en_construction', 'accepte'],
        shared_with_me: '1',
        search: 'noise'
      ).permit(:procedure_id, :shared_with_me, :search, state: [])
    end

    it 'emits a hidden field per scalar filter and one per element for arrays' do
      hidden_names = subject.css('input[type=hidden]').map { |i| i['name'] }
      expect(hidden_names).to contain_exactly('procedure_id', 'state[]', 'state[]', 'shared_with_me')
    end

    it 'excludes the search filter from hidden fields' do
      hidden_names = subject.css('input[type=hidden]').map { |i| i['name'] }
      expect(hidden_names).not_to include('search')
    end
  end
end
