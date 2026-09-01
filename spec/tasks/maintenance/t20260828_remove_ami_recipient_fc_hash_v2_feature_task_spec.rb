# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260828RemoveAmiRecipientFcHashV2FeatureTask do
    let(:features) { Flipper::Adapters::ActiveRecord::Feature }
    let(:gates) { Flipper::Adapters::ActiveRecord::Gate }

    before do
      @previous_flipper = Flipper.instance
      Flipper.instance = Flipper.new(Flipper::Adapters::ActiveRecord.new)
    end

    after { Flipper.instance = @previous_flipper }

    describe "the list itself" do
      it 'never targets a flag the code still declares' do
        declared = Rails.root.join('config/initializers/flipper.rb').read
          .scan(/^\s*:(\w+),?\s*$/).flatten

        expect(described_class::OBSOLETE_FEATURES.map(&:to_s) & declared).to be_empty
      end
    end

    describe "#process" do
      subject(:process) { described_class::OBSOLETE_FEATURES.each { described_class.process(it) } }

      it 'removes the obsolete row' do
        Flipper.add(:ami_recipient_fc_hash_v2)

        expect { process }
          .to change { features.where(key: 'ami_recipient_fc_hash_v2').count }.from(1).to(0)
      end

      it 'removes the gates left behind by the fully-enabled flag' do
        Flipper.enable(:ami_recipient_fc_hash_v2)

        expect { process }
          .to change { gates.where(feature_key: 'ami_recipient_fc_hash_v2').count }.to(0)
      end

      it 'leaves the flags still in use alone' do
        Flipper.add(:ami_notifications)
        Flipper.enable(:ami_notifications)

        expect { process }.not_to change { features.where(key: 'ami_notifications').count }
        expect(Flipper.enabled?(:ami_notifications)).to be true
      end

      it 'is idempotent: a key already absent is not an error' do
        expect { process }.not_to raise_error
        expect { process }.not_to raise_error
      end
    end
  end
end
