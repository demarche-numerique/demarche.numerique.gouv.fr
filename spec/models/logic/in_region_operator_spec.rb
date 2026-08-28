# frozen_string_literal: true

describe Logic::InRegionOperator do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes }, { type: :epci }, { type: :departements }]) }
  let(:dossier) { create(:dossier, procedure:) }

  let(:tdc_commune) { procedure.active_revision.type_de_champs.first }
  let(:champ_commune) do
    Champs::CommuneChamp.new(code_postal: '92500', external_id: '92063', stable_id: tdc_commune.stable_id, dossier:)
      .tap { |c| c.send(:on_codes_change) } # private method called before save to fill value, which is required for compute
  end

  let(:tdc_epci) { procedure.active_revision.type_de_champs.second }
  let(:champ_epci) do
    Champs::EpciChamp.new(code_departement: '43', code_region: '32', external_id: '244301016', stable_id: tdc_epci.stable_id, dossier:)
      .tap do |c|
        c.send(:on_epci_name_changes)
      end # private method called before save to fill value, which is required for compute
  end

  let(:tdc_departement) { procedure.active_revision.type_de_champs.third }
  let(:champ_departement) { Champs::DepartementChamp.new(value: '01', stable_id: tdc_departement.stable_id, dossier:) }

  describe '#compute' do
    context 'commune' do
      it { expect(ds_in_region(champ_value(champ_commune.stable_id), constant('11')).compute([champ_commune])).to be(true) }
    end

    context 'epci' do
      it do
        expect(ds_in_region(champ_value(champ_epci.stable_id), constant('84')).compute([champ_epci])).to be(true)
      end
    end

    context 'departement' do
      it { expect(ds_in_region(champ_value(champ_departement.stable_id), constant('84')).compute([champ_departement])).to be(true) }
    end

    context 'departement Etranger' do
      let(:champ_departement) { Champs::DepartementChamp.new(value: '99', stable_id: tdc_departement.stable_id, dossier:) }

      it 'is in the region Etranger' do
        expect(ds_in_region(champ_value(champ_departement.stable_id), constant('99')).compute([champ_departement])).to be(true)
        expect(ds_in_region(champ_value(champ_departement.stable_id), constant('84')).compute([champ_departement])).to be(false)
      end
    end
  end
end
