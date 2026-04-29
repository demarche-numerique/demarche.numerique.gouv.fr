# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::PendingTransfersBannerComponent, type: :component do
  context 'with no pending transfers' do
    subject { render_inline(described_class.new(count: 0)) }

    it 'renders nothing' do
      expect(subject.to_html.strip).to be_empty
    end
  end

  context 'with one pending transfer' do
    subject { render_inline(described_class.new(count: 1)) }

    it 'renders the title' do
      expect(subject.to_html).to include('Demandes de transfert de dossier')
    end

    it 'renders the singular link label' do
      expect(subject.to_html).to include('Voir la demande en attente (1)')
    end
  end

  context 'with multiple pending transfers' do
    subject { render_inline(described_class.new(count: 3)) }

    it 'renders the plural link label' do
      expect(subject.to_html).to include('Voir les demandes en attente (3)')
    end
  end
end
