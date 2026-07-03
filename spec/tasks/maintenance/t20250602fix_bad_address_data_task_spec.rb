# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20250602fixBadAddressDataTask do
    describe "#process" do
      subject(:process) { described_class.process(address_champ) }
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:address_champ) { dossier.project_champs_public.first }

      context "when the address is a partial address with international data" do
        let(:value_json) do
          {
            "not_in_ban" => "true",
            "country_code" => "CH",
            "street_address" => "128 rue brancion, paris 75015",
          }
        end
        before { address_champ.update_columns(value: "123 Main St", value_json:) }

        it do
          expect { process }
            .to change { address_champ.reload.department_code }
            .from(nil).to("99")
        end
      end

      context "when the address is france not ban but department code is still international" do
        let(:value_json) do
          {
            "not_in_ban" => "true",
            "country_code" => "FR",
            "city_code" => "75115",
            "postal_code" => "75015",
            "street_address" => "128 rue brancion, paris 75015",
            "department_code" => "99",
            "department_name" => "Etranger",
          }
        end

        before { address_champ.update_columns(value_json:) }

        it do
          expect { process }.to change { address_champ.reload.value_json }.to({
            "city_code" => "75115",
           "city_name" => "Paris 15e Arrondissement",
           "not_in_ban" => "true",
           "postal_code" => "75015",
           "region_code" => "11",
           "region_name" => "Île-de-France",
           "country_code" => "FR",
           "country_name" => "France",
           "street_address" => "128 rue brancion, paris 75015",
           "department_code" => "75",
           "department_name" => "Paris",
          })
        end
      end
    end
  end
end
