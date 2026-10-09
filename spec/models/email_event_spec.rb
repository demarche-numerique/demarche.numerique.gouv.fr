# frozen_string_literal: true

RSpec.describe EmailEvent, type: :model do
  describe '.create_from_message!' do
    it 'records one event per bcc recipient of a mail with no To' do
      message = Mail.new(bcc: ['a@example.com', 'b@example.com'], subject: 'Ajout')

      described_class.create_from_message!(message, status: 'dispatched')

      expect(described_class.where(subject: 'Ajout').pluck(:to)).to contain_exactly('a@example.com', 'b@example.com')
    end
  end
end
