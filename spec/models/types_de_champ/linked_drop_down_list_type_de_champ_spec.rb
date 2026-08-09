# frozen_string_literal: true

describe TypesDeChamp::LinkedDropDownListTypeDeChamp do
  let(:type_de_champ) { build(:type_de_champ_linked_drop_down_list, drop_down_options: menu_options) }

  subject { type_de_champ.dynamic_type }

  describe 'validation' do
    context 'the menu must start with one primary option (validated on the procedure)' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :linked_drop_down_list, libelle: 'liaison', options: menu_options }]) }

      def tdc_in_error
        procedure.errors.find { it.attribute == :draft_types_de_champ_public }.options[:type_de_champ]
      end

      context 'valid menu' do
        let(:menu_options) do
          [
            "--Primary 1--",
            "secondary 1.1",
            "secondary 1.2",
            "--Primary 2--",
            "secondary 2.1",
            "secondary 2.2",
            "secondary 2.3",
          ]
        end

        it { expect(procedure.validate(:types_de_champ_public_editor)).to be true }
      end

      context 'degenerate but valid menu' do
        let(:menu_options) { ["--Primary 1--"] }

        it { expect(procedure.validate(:types_de_champ_public_editor)).to be true }
      end

      context 'starting with secondary options' do
        let(:menu_options) do
          [
            "secondary 1.1",
            "secondary 1.2",
            "--Primary 2--",
            "secondary 2.1",
            "secondary 2.2",
            "secondary 2.3",
          ]
        end

        it 'adds the error on the procedure, pointing at the type de champ' do
          expect(procedure.validate(:types_de_champ_public_editor)).to be false
          expect(tdc_in_error.libelle).to eq('liaison')
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_public))
            .to eq(['Le champ doit commencer par une entrée de menu primaire de la forme --texte--'])
        end
      end
    end
  end

  describe '#unpack_options' do
    context 'with no options' do
      let(:menu_options) { [] }
      it do
        expect(subject.secondary_options).to eq({})
        expect(subject.primary_options).to eq([])
      end
    end

    context 'with two primary options' do
      let(:menu_options) do
        [
          "--Primary 1--",
          "secondary 1.1",
          "secondary 1.2",
          "--Primary 2--",
          "secondary 2.1",
          "secondary 2.2",
          "secondary 2.3",
        ]
      end

      context "mandatory tdc" do
        it do
          expect(subject.secondary_options).to eq(
            {
              'Primary 1' => ['secondary 1.1', 'secondary 1.2'],
              'Primary 2' => ['secondary 2.1', 'secondary 2.2', 'secondary 2.3'],
            }
          )
          expect(subject.primary_options).to eq(['Primary 1', 'Primary 2'])
        end
      end

      context "not mandatory" do
        let(:type_de_champ) { build(:type_de_champ_linked_drop_down_list, drop_down_options: menu_options, mandatory: false) }

        it do
          expect(subject.secondary_options).to eq(
            {
              'Primary 1' => ['secondary 1.1', 'secondary 1.2'],
              'Primary 2' => ['secondary 2.1', 'secondary 2.2', 'secondary 2.3'],
            }
          )
          expect(subject.primary_options).to eq(['Primary 1', 'Primary 2'])
        end
      end
    end
  end
end
