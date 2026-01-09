# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe PopulateSiretValueJSONTask do
    describe "#process" do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:element) { dossier.champs.first }
      subject(:process) { described_class.process(element) }

      before do
        element.update!(value_json: nil)
      end

      it 'updates value_json' do
        expect { subject }.to change { element.reload.value_json }
          .from(anything)
          .to({
            "city_code" => "92009",
            "city_name" => "Bois-Colombes",
            "postal_code" => "92270",
            "region_code" => "11",
            "region_name" => "Île-de-France",
            "street_name" => "RAOUL NORDLING",
            "street_number" => "6",
            "street_address" => "6 RUE RAOUL NORDLING",
            "departement_code" => "92",
            "department_code" => "92",
            "departement_name" => "Hauts-de-Seine",
            "department_name" => "Hauts-de-Seine",
            "country_code" => "FR",
            "country_name" => "France",

            "entreprise_date_creation" => "1990-04-24",
            "entreprise_forme_juridique" => "SA à conseil d’administration (s.a.i.)",
            "entreprise_nom_commercial" => "GRTGAZ",
            "entreprise_raison_sociale" => "GRTGAZ",
            "entreprise_siren" => "440117620",
            "libelle_naf" => "Transports par conduites",
          })
      end
    end
  end
end
