# frozen_string_literal: true

describe TypesDeChamp::PreRempliTypeDeChamp do
  let(:types_de_champ_public) { [{ type: :pre_rempli }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first }
  let(:type_de_champ) { champ.type_de_champ }

  describe '#tags_for_template' do
    it 'returns tags with libelle' do
      tags = type_de_champ.tags_for_template
      expect(tags).to be_an(Array)
      expect(tags.first[:libelle]).to include(type_de_champ.libelle)
    end
  end

  describe '#options_for_select' do
    context 'with drop_down_options' do
      before { type_de_champ.update!(drop_down_options_from_text: "En cours\r\nIdée\r\nFait") }

      it 'returns options as pairs' do
        expect(type_de_champ.options_for_select).to eq([["En cours", "En cours"], ["Idée", "Idée"], ["Fait", "Fait"]])
      end
    end

    context 'without drop_down_options' do
      it 'returns empty array' do
        expect(type_de_champ.options_for_select).to eq([])
      end
    end
  end

  describe '#pre_rempli_hidden?' do
    it 'returns false by default' do
      expect(type_de_champ.pre_rempli_hidden?).to be false
    end

    context 'when pre_rempli_hidden is "1"' do
      before { type_de_champ.update!(pre_rempli_hidden: "1") }

      it { expect(type_de_champ.pre_rempli_hidden?).to be true }
    end
  end
end
