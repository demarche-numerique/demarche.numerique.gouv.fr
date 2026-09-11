# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260731cleanServiceSiretTask do
    describe "#process" do
      subject(:process) { described_class.process(element) }
      let(:element) {
        # Object to be processed in a single iteration of this task
      }
      pending "add some examples to (or delete) #{__FILE__}"
    end
  end
end
