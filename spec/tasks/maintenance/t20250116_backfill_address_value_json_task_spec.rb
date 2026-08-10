# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20250116BackfillAddressValueJSONTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address, libelle: 'address' }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:address_champ) { dossier.root_public_champs.first }
      let(:address_data) { { 'address' => 'address', 'country_code' => 'FR' } }

      before { address_champ.update(data: address_data) }

      it do
        expect(address_champ.value_json).to be_nil

        described_class.process(address_champ)
        address_champ.reload

        expect(address_champ.value_json).to eq(address_data)
      end
    end
  end
end
