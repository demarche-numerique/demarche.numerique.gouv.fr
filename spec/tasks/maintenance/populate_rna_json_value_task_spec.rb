# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe PopulateRNAJSONValueTask do
    describe "#process" do
      include Dry::Monads[:result]

      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rna }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
      let(:element) { dossier.project_champs_public.first }
      let(:body) { File.read('spec/fixtures/files/api_entreprise/associations.json') }
      let(:data_source) { JSON.parse(body).with_indifferent_access }
      let(:data) { data_source[:data] }
      let(:meta) { data_source[:meta] }
      let(:processed_params) do
        {
          "association_rna" => data[:rna],
          "association_titre" => data[:nom],
          "association_objet" => data[:activites][:objet],
          "association_date_creation" => data[:date_creation],
          "association_date_declaration" => meta[:date_derniere_mise_a_jour_rna],
          "association_date_publication" => data[:date_publication_journal_officiel],
          "adresse" => data[:adresse_siege],
        }
      end

      subject(:process) { described_class.process(element.champ_data) }

      before do
        allow_any_instance_of(Champs::RNAChamp).to receive(:fetch_external_data).and_return(
          Success(
            data: processed_params,
            value_json: element.send(:extract_value_json, data: processed_params),
            value: element.value
          )
        )
      end

      it 'updates value_json' do
        expect { subject }.to change { element.reload.value_json }
          .from(anything)
          .to({
            "title" => "LA PRÉVENTION ROUTIERE",
            "city_code" => "75108",
            "city_name" => "Paris",
            "postal_code" => "75009",
            "region_code" => nil,
            "region_name" => nil,
            "street_name" => "de Modagor",
            "country_code" => "FR",
            "country_name" => "France",
            "street_number" => "33",
            "street_address" => "33 rue de Modagor",
            "association_rna" => "W751080001",
            "department_code" => nil,
            "department_name" => nil,
            "departement_code" => nil,
            "departement_name" => nil,
            "association_objet" =>
            "L’association a pour objet de promouvoir la pratique du sport de haut niveau et de contribuer à la formation des jeunes sportifs.",
            "association_date_creation" => "2015-01-01",
            "association_date_declaration" => "2019-01-01",
            "association_date_publication" => "2018-01-01",
          })
      end
    end
  end
end
