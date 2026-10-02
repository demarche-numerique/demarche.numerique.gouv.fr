# frozen_string_literal: true

describe TypesDeChamp::CarteTypeDeChamp do
  describe 'parcelle layers exclusivity' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte, libelle: 'La carte' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }

    it 'keeps rpg when it is enabled on a carte already using cadastres' do
      tdc.update!(editable_options: { cadastres: '1' })
      tdc.update!(editable_options: { rpg: '1' })

      expect(tdc.carte_optional_layers).to eq([:rpg])
    end

    it 'keeps cadastres when it is enabled on a carte already using rpg' do
      tdc.update!(editable_options: { rpg: '1' })
      tdc.update!(editable_options: { cadastres: '1' })

      expect(tdc.carte_optional_layers).to eq([:cadastres])
    end

    it 'keeps cadastres when both layers are enabled at once' do
      tdc.update!(editable_options: { cadastres: '1', rpg: '1' })

      expect(tdc.carte_optional_layers).to eq([:cadastres])
    end

    it 'leaves the other layers untouched' do
      tdc.update!(editable_options: { cadastres: '1', znieff: '1' })

      expect(tdc.carte_optional_layers).to eq([:cadastres, :znieff])
    end

    it 'lists cadastres only on a carte saved with both layers before they were exclusive' do
      tdc.update_column(:options, { cadastres: '1', rpg: '1', znieff: '1' })

      expect(tdc.reload.carte_optional_layers).to eq([:cadastres, :znieff])
    end
  end
end
