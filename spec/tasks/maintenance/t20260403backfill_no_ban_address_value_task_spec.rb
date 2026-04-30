# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260403backfillNoBanAddressValueTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address, libelle: 'address' }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:address_champ) { dossier.project_champs_public.first }

      subject(:process) { described_class.process(address_champ) }

      context "when value is blank, not ban, and full_address is true" do
        before do
          address_champ.update_columns(
            value: nil,
            value_json: {
              "label" => "19 rue Neuve d'Argenson, Bergerac 24100",
              "country_code" => "FR",
              "street_address" => "19 rue Neuve d'Argenson",
              "city_code" => "Bergerac",
              "not_in_ban" => "true",
            }
          )
        end

        it "backfills value with label" do
          subject
          expect(address_champ.reload.value).to eq("19 rue Neuve d'Argenson, Bergerac 24100")
        end
      end

      context "when value is already present" do
        before do
          address_champ.update_columns(
            value: "une autre adresse",
            value_json: {
              "label" => "19 rue Neuve d'Argenson, Bergerac 24100",
              "country_code" => "FR",
              "street_address" => "19 rue Neuve d'Argenson",
              "city_code" => "Bergerac",
              "not_in_ban" => "true",
            }
          )
        end

        it "does not override value" do
          subject
          expect(address_champ.reload.value).to eq("une autre adresse")
        end
      end

      context "when address is BAN" do
        before do
          address_champ.update_columns(
            value: "une autre adresse",
            value_json: {
              "label" => "19 rue Neuve d'Argenson, Bergerac 24100",
              "city_name" => "Bergerac",
              "city_code" => "24100",
              "postal_code" => "24100",
              "region_code" => "75",
              "region_name" => "Nouvelle-Aquitaine",
              "country_code" => "FR",
              "country_name" => "France",
              "street_address" => "19 rue Neuve d'Argenson",
              "department_code" => "24",
              "department_name" => "Dordogne",
              "not_in_ban" => "false",
            }
          )
        end

        it "does not override value" do
          subject
          expect(address_champ.reload.value).to eq("une autre adresse")
        end
      end

      context "when address is not full" do
        before do
          address_champ.update_columns(
            value: nil,
            value_json: {
              "label" => "adresse incomplète",
              "street_address" => "19 rue Neuve d'Argenson",
              "not_in_ban" => "true",
            }
          )
        end

        it "does not update value" do
          subject
          expect(address_champ.reload.value).to eq(nil)
        end
      end
    end
  end
end
