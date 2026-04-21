# frozen_string_literal: true

describe Logic::ChampValue do
  include Logic

  describe '#compute' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: tdc_type, drop_down_other: }]) }
    let(:drop_down_other) { nil }
    let(:tdc_type) { :text }
    let(:tdc) { procedure.active_revision.types_de_champ.first }
    let(:dossier) { create(:dossier, procedure:) }

    subject { champ_value(champ.stable_id).compute([champ]) }

    context 'yes_no tdc' do
      let(:tdc_type) { :yes_no }
      let(:champ) { Champs::YesNoChamp.new(value: value, stable_id: tdc.stable_id, dossier:) }
      let(:value) { 'true' }

      it { expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:boolean) }

      context 'with true value' do
        it { is_expected.to be(true) }
      end

      context 'with false value' do
        let(:value) { 'false' }

        it { is_expected.to be(false) }
      end

      context 'with a value not visible' do
        before do
          expect(champ).to receive(:visible?).and_return(false)
        end

        it { is_expected.to be nil }
      end
    end

    context 'integer tdc' do
      let(:tdc_type) { :integer_number }
      let(:champ) { Champs::IntegerNumberChamp.new(value:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { '42' }

      it do
        expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:number)
        is_expected.to eq(42)
      end

      context 'with a blank value' do
        let(:value) { '' }

        it { is_expected.to be nil }
      end
    end

    context 'decimal tdc' do
      let(:tdc_type) { :decimal_number }
      let(:champ) { Champs::DecimalNumberChamp.new(value:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { '42.01' }

      it do
        expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:number)
        is_expected.to eq(42.01)
      end
    end

    context 'dropdown tdc' do
      let(:tdc_type) { :drop_down_list }
      let(:champ) { Champs::DropDownListChamp.new(value:, other:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { 'val1' }
      let(:other) { nil }

      it do
        expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:enum)
        is_expected.to eq('val1')
        expect(champ_value(champ.stable_id).options([champ.type_de_champ])).to match_array([["val1", "val1"], ["val2", "val2"], ["val3", "val3"]])
      end

      context 'with other enabled' do
        let(:tdc_type) { :drop_down_list }
        let(:drop_down_other) { true }

        it do
          is_expected.to eq('val1')
          expect(champ_value(champ.stable_id).options([champ.type_de_champ])).to match_array([["val1", "val1"], ["val2", "val2"], ["val3", "val3"], [I18n.t('shared.champs.drop_down_list.other'), "__other__"]])
        end

        context 'with other filled' do
          let(:other) { true }

          it { is_expected.to eq(Champs::DropDownListChamp::OTHER) }
        end
      end
    end

    context 'checkbox tdc' do
      let(:tdc_type) { :checkbox }
      let(:champ) { Champs::CheckboxChamp.new(value:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { 'true' }

      it do
        expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:boolean)
        is_expected.to eq(true)
      end
    end

    context 'departement tdc' do
      let(:tdc_type) { :departements }
      let(:champ) { Champs::DepartementChamp.new(value:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { '02' }

      it do
        expect(champ_value(champ.stable_id).type([champ.type_de_champ])).to eq(:departement_enum)
        is_expected.to eq({ value: '02', code_region: '32' })
      end
    end

    context 'region tdc' do
      let(:tdc_type) { :regions }
      let(:champ) { Champs::RegionChamp.new(value:, stable_id: tdc.stable_id, dossier:) }
      let(:value) { 'La Réunion' }

      it { is_expected.to eq('04') }
    end

    context 'commune tdc' do
      let(:tdc_type) { :communes }
      let(:champ) do
        Champs::CommuneChamp.new(code_postal:, external_id:, stable_id: tdc.stable_id, dossier:)
          .tap { |c| c.send(:on_codes_change) } # private method called before save to fill value, which is required for compute
      end
      let(:code_postal) { '92500' }
      let(:external_id) { '92063' }

      it do
        is_expected.to eq({ code_departement: '92', code_region: '11' })
      end

      context 'in fallback mode (not_in_api_geo)' do
        let(:champ) do
          Champs::CommuneChamp.new(value: 'Ma commune', not_in_api_geo: 'true', stable_id: tdc.stable_id, dossier:)
        end

        it { is_expected.to eq({ code_departement: nil, code_region: nil }) }
      end
    end

    context 'epci tdc' do
      let(:tdc_type) { :epci }
      let(:champ) do
        Champs::EpciChamp.new(code_departement:, external_id:, stable_id: tdc.stable_id, dossier:)
          .tap { |c| c.send(:on_epci_name_changes) } # private method called before save to fill value, which is required for compute
      end
      let(:code_departement) { '43' }
      let(:external_id) { '244301016' }

      it { is_expected.to eq({ code_departement: '43', code_region: '84' }) }
    end

    describe 'errors' do
      let(:tdc_type) { :number }
      let(:champ) { Champs::IntegerNumberChamp.new(value: nil, stable_id: tdc.stable_id, dossier:) }

      it do
        expect(champ_value(champ.stable_id).errors([champ.type_de_champ])).to be_empty
        expect(champ_value(champ.stable_id).errors([])).to eq([{ type: :not_available }])
      end
    end

    describe '#sources' do
      let(:tdc_type) { :number }
      let(:champ) { Champs::IntegerNumberChamp.new(value: nil, stable_id: tdc.stable_id, dossier:) }

      it { expect(champ_value(champ.stable_id).sources).to eq([champ.stable_id]) }
    end

    context 'with multiple revision' do
      let(:options) { ['revision_1'] }
      let(:procedure) do
        create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :drop_down_list, libelle: 'dropdown', options: options }])
      end
      let(:drop_down_r1) { procedure.published_revision.types_de_champ_public.first }
      let(:stable_id) { drop_down_r1.stable_id }

      it { expect(champ_value(stable_id).options([drop_down_r1])).to match_array([["revision_1", "revision_1"]]) }

      context 'with a new revision' do
        let(:drop_down_r2) { procedure.draft_revision.types_de_champ_public.first }

        before do
          tdc = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc.drop_down_options = ['revision_2']
          tdc.save!
        end

        it do
          expect(champ_value(stable_id).options([drop_down_r2])).to match_array([["revision_2", "revision_2"]])
        end
      end
    end
  end
end
