# frozen_string_literal: true

describe TypesDeChamp::LinkedDropDownList do
  # On creation (type_champ_changed?) set_drop_down_list_options would overwrite an invalid menu.
  let(:type_de_champ) { create(:type_de_champ_linked_drop_down_list).tap { _1.drop_down_options = menu_options } }

  subject { type_de_champ }

  describe 'validation' do
    context 'It must start with one primary option' do
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

        it { is_expected.to be_valid }
      end

      context 'degenerate but valid menu' do
        let(:menu_options) { ["--Primary 1--"] }

        it { is_expected.to be_valid }
      end

      context 'invalid menus' do
        shared_examples 'missing primary option' do
          it do
            is_expected.to be_invalid
            subject.validate
            expect(subject.errors.full_messages).to eq ["Le champ « #{subject.libelle} » doit commencer par une entrée de menu primaire de la forme <code style='white-space: pre-wrap;'>--texte--</code>"]
          end
        end

        context 'no primary option' do
          let(:menu_options) { ["secondary 1.1", "secondary 1.2"] }

          it_should_behave_like 'missing primary option'
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

          it_should_behave_like 'missing primary option'
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
