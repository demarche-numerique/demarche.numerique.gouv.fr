# frozen_string_literal: true

describe API::V2::ParsedQueryCache do
  before { described_class.clear }
  after { described_class.clear }

  it 'parses once and returns the same document for identical query strings' do
    query = 'query Q { a }'

    expect(GraphQL).to receive(:parse).once.and_call_original

    document = described_class.fetch(query)
    expect(document).to be_a(GraphQL::Language::Nodes::Document)
    expect(described_class.fetch(query)).to equal(document)
  end

  it 'returns nil for blank or unparseable query strings' do
    expect(described_class.fetch(nil)).to be_nil
    expect(described_class.fetch('')).to be_nil
    expect(described_class.fetch('query Q {')).to be_nil
  end

  it 'evicts the least recently used entry beyond MAX_ENTRIES' do
    stub_const("#{described_class}::MAX_ENTRIES", 2)

    document = described_class.fetch('query Q1 { a }')
    described_class.fetch('query Q2 { a }')
    described_class.fetch('query Q1 { a }') # refresh Q1
    described_class.fetch('query Q3 { a }') # evicts Q2, the least recently used

    # Q1 survived the eviction; only Q2 needs a re-parse.
    expect(GraphQL).to receive(:parse).once.and_call_original
    expect(described_class.fetch('query Q1 { a }')).to equal(document)
    described_class.fetch('query Q2 { a }')
  end
end
