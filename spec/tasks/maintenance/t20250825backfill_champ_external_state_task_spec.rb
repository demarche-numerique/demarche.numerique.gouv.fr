# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20250825backfillChampExternalStateTask do
      xdescribe "#process" do
        subject(:process) { described_class.process(champ) }
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :referentiel }]) }
        let(:dossier) { create(:dossier, procedure:) }
        let(:champ) { dossier.root_public_champs.first }

        context "when external_data_fetched? is true" do
          before { allow(champ).to receive(:external_data_fetched?).and_return(true) }

          it { expect { process }.to change { champ.external_state }.from("idle").to('fetched') }
        end

        context "when external_error_present? is true" do
          before { allow(champ).to receive(:external_error_present?).and_return(true) }

          it { expect { process }.to change { champ.external_state }.from("idle").to('external_error') }
        end

        context 'when an not found in Revision error occurs' do
          before { allow(champ).to receive(:external_data_fetched?).and_raise(StandardError, "not found in Revision") }

          it 'does not change external_state and does not rase errors' do
            expect { process }.not_to raise_error
            expect(champ.external_state).to eq("idle")
          end
        end
      end
    end
end
