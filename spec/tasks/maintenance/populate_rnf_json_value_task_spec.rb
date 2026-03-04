# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe PopulateRNFJSONValueTask do
    describe "#process" do
      include Dry::Monads[:result]
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rnf }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:element) { dossier.champs.first }
      let(:data) do
        {
          id: 3,
          rnfId: '075-FDD-00003-01',
          type: 'FDD',
          department: '75',
          title: 'Fondation SFR',
          dissolvedAt: nil,
          phone: '+33185060000',
          email: 'fondation@sfr.fr',
          addressId: 3,
          createdAt: "2023-09-07T13:26:10.358Z",
          updatedAt: "2023-09-07T13:26:10.358Z",
          address: {
            id: 3,
            createdAt: "2023-09-07T13:26:10.358Z",
            updatedAt: "2023-09-07T13:26:10.358Z",
            label: "16 Rue du Général de Boissieu 75015 Paris",
            type: "housenumber",
            streetAddress: "16 Rue du Général de Boissieu",
            streetNumber: "16",
            streetName: "Rue du Général de Boissieu",
            postalCode: "75015",
            cityName: "Paris",
            cityCode: "75115",
            departmentName: "Paris",
            departmentCode: "75",
            regionName: "Île-de-France",
            regionCode: "11",
          },
          status: nil,
          persons: [],
        }
      end

      subject(:process) { described_class.process(element) }

      context 'when api respond ok' do
        before do
          allow_any_instance_of(RNFService).to receive(:call).and_return(Success(data))
        end

        it 'updates value_json' do
          expect { subject }.to change { element.reload.value_json }
            .from(anything)
            .to({
              "street_number" => "16",
              "street_name" => "Rue du Général de Boissieu",
              "street_address" => "16 Rue du Général de Boissieu",
              "postal_code" => "75015",
              "city_name" => "Paris 15e Arrondissement",
              "city_code" => "75115",
              "departement_code" => "75",
              "department_code" => "75",
              "departement_name" => "Paris",
              "department_name" => "Paris",
              "region_code" => "11",
              "region_name" => "Île-de-France",
              "title" => "Fondation SFR",
              "country_name" => "France",
              "country_code" => "FR",
            })
        end
      end

      context 'when api respond KO' do
        before do
          element.update(data:)
          allow_any_instance_of(Champs::RNFChamp).to receive(:fetch_external_data).and_return(Failure(code: 404, error: :removed))
        end

        it 'updates value_json' do
          expect { subject }.to change { element.reload.value_json }
            .from(anything)
            .to({
              "street_number" => "16",
              "street_name" => "Rue du Général de Boissieu",
              "street_address" => "16 Rue du Général de Boissieu",
              "postal_code" => "75015",
              "city_name" => "Paris 15e Arrondissement",
              "city_code" => "75115",
              "departement_code" => "75",
              "department_code" => "75",
              "departement_name" => "Paris",
              "department_name" => "Paris",
              "region_code" => "11",
              "region_name" => "Île-de-France",
              "title" => "Fondation SFR",
              "country_name" => "France",
              "country_code" => "FR",
            })
        end
      end
    end
  end
end
