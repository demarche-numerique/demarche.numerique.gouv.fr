# frozen_string_literal: true

RSpec.describe Attachment::DropZoneDecorator do
  describe 'integrated mode' do
    subject { described_class.new(mode: :integrated) }

    it 'generates drop-target controller attributes' do
      attrs = subject.data_attributes
      expect(attrs[:controller]).to eq('drop-target')
      expect(attrs[:action]).to include('drop->drop-target#onDrop')
    end

    it 'does not include input selector' do
      attrs = subject.data_attributes
      expect(attrs).not_to have_key(:'drop-target-input-selector-value')
    end

    it 'provides CSS class' do
      expect(subject.css_class).to eq('attachment-drop-zone')
    end
  end

  describe 'remote mode' do
    subject { described_class.new(input_selector: '#file-msg-123', mode: :remote) }

    it 'includes input selector value' do
      attrs = subject.data_attributes
      expect(attrs[:'drop-target-input-selector-value']).to eq('#file-msg-123')
    end

    it 'requires input_selector' do
      expect {
        described_class.new(mode: :remote)
      }.to raise_error(ArgumentError, /input_selector is required/)
    end
  end

  describe '#merge_into' do
    subject { described_class.new(mode: :integrated) }

    it 'merges CSS classes' do
      result = subject.merge_into(class: 'fr-input')
      expect(result[:class]).to eq('fr-input attachment-drop-zone')
    end

    it 'merges data attributes' do
      result = subject.merge_into(data: { foo: 'bar' })
      expect(result[:data][:foo]).to eq('bar')
      expect(result[:data][:controller]).to eq('drop-target')
    end
  end
end
