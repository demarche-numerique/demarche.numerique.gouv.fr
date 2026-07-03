# frozen_string_literal: true

describe Logic::NotInDepartementOperator do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :communes }, { type: :epci }]) }
  let(:dossier) { create(:dossier, procedure:) }

  let(:tdc_commune) { procedure.active_revision.types_de_champ.first }
  let(:champ_commune) do
    build_projected_champ(tdc_commune, dossier:, external_id: '92063')
      .tap { |c| c.code_postal = '92500'; c.send(:on_codes_change) } # private method called before save to fill value, which is required for compute
  end

  let(:tdc_epci) { procedure.active_revision.types_de_champ.second }
  let(:champ_epci) do
    build_projected_champ(tdc_epci, dossier:, external_id: '244301016')
      .tap do |c|
        c.code_departement = '43'
        c.code_region = '32'
        c.send(:on_epci_name_changes)
      end # private method called before save to fill value, which is required for compute
  end

  describe '#compute' do
    context 'commune' do
      it do
        expect(ds_not_in_departement(champ_value(champ_commune.stable_id), constant('93')).compute([champ_commune])).to be(true)
        expect(ds_not_in_departement(champ_value(champ_commune.stable_id), constant('92')).compute([champ_commune])).to be(false)
      end
    end

    context 'epci' do
      it do
        expect(ds_not_in_departement(champ_value(champ_epci.stable_id), constant('43')).compute([champ_epci])).to be(false)
        expect(ds_not_in_departement(champ_value(champ_epci.stable_id), constant('03')).compute([champ_epci])).to be(true)
      end
    end
  end
end
