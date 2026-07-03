# frozen_string_literal: true

describe Logic::IncludeOperator do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list }]) }
  let(:tdc) { procedure.active_revision.types_de_champ.first }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { build_projected_champ(tdc, dossier:, value: '["val1", "val2"]') }

  describe '#compute' do
    it do
      expect(ds_include(champ_value(champ.stable_id), constant('val1')).compute([champ])).to be(true)
      expect(ds_include(champ_value(champ.stable_id), constant('something else')).compute([champ])).to be(false)
    end
  end

  describe '#errors' do
    # rubocop:disable RSpec/ConsecutiveItBlocks
    it { expect(ds_include(champ_value(champ.stable_id), constant('val1')).errors([champ.type_de_champ])).to be_empty }
    it do
      expected = {
        right: constant('something else'),
        stable_id: champ.stable_id,
        type: :not_included,
      }

      expect(ds_include(champ_value(champ.stable_id), constant('something else')).errors([champ.type_de_champ])).to eq([expected])
    end

    it { expect(ds_include(constant(1), constant('val1')).errors([])).to eq([{ type: :required_list }]) }
    # rubocop:enable RSpec/ConsecutiveItBlocks
  end

  describe '#==' do
    it { expect(ds_include(champ_value(champ.stable_id), constant('val1'))).to eq(ds_include(champ_value(champ.stable_id), constant('val1'))) }
  end
end
