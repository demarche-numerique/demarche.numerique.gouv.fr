# frozen_string_literal: true

describe Logic::NotInRegionOperator do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :communes }, { type: :epci }, { type: :departements }]) }
  let(:dossier) { create(:dossier, procedure:) }

  let(:tdc_commune) { procedure.active_revision.types_de_champ.first }
  let(:champ_commune) do
    build_projected_champ(tdc_commune, dossier:, external_id: '92063')
      .tap { |c| c.code_postal = '92500' }
      .tap { |c| c.send(:on_codes_change) } # private method called before save to fill value, which is required for compute
  end

  let(:tdc_epci) { procedure.active_revision.types_de_champ.second }
  let(:champ_epci) do
    build_projected_champ(tdc_epci, dossier:, external_id: '244301016')
      .tap { |c| c.code_departement = '43' }
      .tap do |c|
        c.send(:on_epci_name_changes)
      end # private method called before save to fill value, which is required for compute
  end

  let(:tdc_departement) { procedure.active_revision.types_de_champ.third }
  let(:champ_departement) { build_projected_champ(tdc_departement, dossier:, value: nil).tap { |c| c.value = '01' } }

  # let(:champ_commune) { create(:champ_communes, code_postal: '92500', external_id: '92063') }
  # let(:champ_epci) { create(:champ_epci, code_departement: '02', code_region: "32") }
  # let(:champ_departement) { create(:champ_departements, value: '01', code_region: '84') }

  describe '#compute' do
    context 'commune' do
      it do
        expect(ds_not_in_region(champ_value(champ_commune.stable_id), constant('11')).compute([champ_commune])).to be(false)
        expect(ds_not_in_region(champ_value(champ_commune.stable_id), constant('32')).compute([champ_commune])).to be(true)
      end
    end

    context 'epci' do
      it do
        expect(ds_not_in_region(champ_value(champ_epci.stable_id), constant('84')).compute([champ_epci])).to be(false)
        expect(ds_not_in_region(champ_value(champ_epci.stable_id), constant('11')).compute([champ_epci])).to be(true)
      end
    end

    context 'departement' do
      it do
        expect(ds_not_in_region(champ_value(champ_departement.stable_id), constant('84')).compute([champ_departement])).to be(false)
        expect(ds_not_in_region(champ_value(champ_departement.stable_id), constant('32')).compute([champ_departement])).to be(true)
      end
    end
  end
end
