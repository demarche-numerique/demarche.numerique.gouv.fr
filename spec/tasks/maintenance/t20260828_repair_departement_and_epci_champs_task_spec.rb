# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260828RepairDepartementAndEpciChampsTask do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :departements }, { type: :epci }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:departement_champ) { dossier.root_champs_public.find { _1.is_a?(Champs::DepartementChamp) } }
    let(:epci_champ) { dossier.root_champs_public.find { _1.is_a?(Champs::EpciChamp) } }
    let(:epci) { APIGeoService.epcis('01').first }
    let(:during_incident) { Time.zone.parse('2026-08-27 10:00') }

    def corrupt(champ, attributes)
      champ.update_columns(attributes.merge(value: nil, updated_at: during_incident))
    end

    describe '#collection' do
      it 'finds the corrupted champs' do
        corrupt(departement_champ, external_id: 'Var')
        corrupt(epci_champ, external_id: epci[:name])

        expect(described_class.new.collection).to contain_exactly(departement_champ, epci_champ)
      end

      it 'ignores champs untouched since the incident started' do
        corrupt(departement_champ, external_id: 'Var')
        departement_champ.update_columns(updated_at: Time.zone.parse('2026-08-20 10:00'))

        expect(described_class.new.collection).to be_empty
      end
    end

    describe '#process' do
      it 'restores the departement code and name' do
        corrupt(departement_champ, external_id: 'Var', value_json: { 'code_region' => nil, 'region_code' => nil, 'department_code' => 'Var' })

        described_class.process(departement_champ)

        expect(departement_champ.reload).to have_attributes(external_id: '83', value: 'Var')
        expect(departement_champ.value_json).to include('department_code' => '83', 'region_code' => '93', 'code_region' => '93')
      end

      it 'restores the EPCI code and name' do
        epci_champ.update!(code_departement: '01')
        corrupt(epci_champ, external_id: epci[:name])

        described_class.process(epci_champ)

        expect(epci_champ.reload).to have_attributes(external_id: epci[:code], value: epci[:name])
      end

      it 'leaves an EPCI without departement untouched' do
        corrupt(epci_champ, external_id: 'CA Haut-Bugey Agglomération')

        expect { described_class.process(epci_champ) }.not_to raise_error
        expect(epci_champ.reload.value).to be_nil
      end

      it 'leaves an EPCI missing from the referentiel untouched' do
        epci_champ.update!(code_departement: '01')
        corrupt(epci_champ, external_id: 'CC Disparue')

        described_class.process(epci_champ)

        expect(epci_champ.reload).to have_attributes(external_id: 'CC Disparue', value: nil)
      end
    end
  end
end
