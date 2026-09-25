# frozen_string_literal: true

describe Logic::NotInDepartementOperator do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes }, { type: :epci }]) }
  let(:dossier) { create(:dossier, procedure:) }

  let(:tdc_commune) { procedure.active_revision.type_de_champs.first }
  let(:champ_commune) do
    Champs::CommuneChamp.new(postal_code: '92500', external_id: '92063', stable_id: tdc_commune.stable_id, dossier:)
      .tap { |c| c.send(:on_codes_change) } # private method called before save to fill value, which is required for compute
  end

  let(:tdc_epci) { procedure.active_revision.type_de_champs.second }
  let(:champ_epci) do
    Champs::EpciChamp.new(department_code: '43', region_code: '32', external_id: '244301016', stable_id: tdc_epci.stable_id, dossier:)
      .tap do |c|
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
