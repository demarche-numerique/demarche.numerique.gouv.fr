# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe UpdateZonesTask do
    describe "#process" do
      subject(:process) { described_class.process(ministere) }
      let(:ministere) {
        {
          "MTEI" => nil,
         "labels" => [{ "2024-03-12" => "Ministère du Travail, de la Santé et des Solidarités" }, { "2022-05-20" => "Ministère du Travail, du Plein emploi et de l’Insertion" }, { "2020-07-06" => "Ministère du Travail" }],
         "tchap_hs" => ["agent.social.tchap.gouv.fr"],
        }
        # Object to be processed in a single iteration of this task
      }
      it 'updates ministere' do
        subject
        expect(Zone.find_by(acronym: 'MTEI').current_label).to eq("Ministère du Travail, de la Santé et des Solidarités")
      end
    end
  end
end
