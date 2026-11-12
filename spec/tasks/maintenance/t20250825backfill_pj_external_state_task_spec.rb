# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20250825backfillPjExternalStateTask do
    xdescribe "#process" do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [{ type: :piece_justificative, nature: 'rib' }])
      end
      let(:dossier) { create(:dossier, procedure:) }
      let(:pj) { dossier.public_root_champs.first }

      subject(:process) { described_class.process(dossier) }

      context "when pj has external_data_fetched? true" do
        before { allow(pj).to receive(:external_data_fetched?).and_return(true) }

        it { expect { process }.to change { pj.external_state }.from("idle").to('fetched') }
      end

      context "when pj has external_error_present? true" do
        before { allow(pj).to receive(:external_error_present?).and_return(true) }

        it { expect { process }.to change { pj.external_state }.from("idle").to('external_error') }
      end
    end
  end
end
