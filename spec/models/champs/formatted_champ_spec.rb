# frozen_string_literal: true

describe Champs::FormattedChamp do
  let(:public_type_de_champs) { [tdc_definition] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.public_root_champs.first }

  before do
    champ.value = value
  end

  describe 'validation' do
    subject { champ.validate(:champ_value) }

    context 'with simple mode' do
      context 'only numbers accepted' do
        let(:tdc_definition) { { type: :formatted, formatted_mode: "simple", numbers_accepted: "1" } }

        context 'with value' do
          let(:value) { "2534" }

          it { is_expected.to be_truthy }
        end

        context 'with invalid value' do
          let(:value) { "cou3872cou" }

          it { is_expected.to be_falsey }
        end
      end

      context 'with minimum chars' do
        let(:tdc_definition) { { type: :formatted, formatted_mode: "simple", letters_accepted: "1", min_character_length: "3" } }

        context 'with value' do
          let(:value) { "ABc" }

          it { is_expected.to be_truthy }
        end

        context 'with invalid value' do
          let(:value) { "AB" }

          it do
            is_expected.to be_falsey
            expect(champ.errors.full_messages_for(:value).first).to include("au moins 3 caractères")
          end
        end
      end
    end

    context 'with advanced mode' do
      context 'with an invalid expression reguliere' do
        let(:value) { "AB-123-CD" }
        let(:tdc_definition) {
          {
            type: :formatted,
            formatted_mode: "advanced",
            expression_reguliere: "[AA-000-ZZ]",
          }
        }

        it 'adds an error instead of raising' do
          expect { subject }.not_to raise_error
          expect(subject).to be_falsey
          expect(champ.errors[:expression_reguliere]).to be_present
        end
      end

      context 'with invalid value' do
        let(:value) { "blop" }
        context 'with expression reguliere error message defined' do
          let(:tdc_definition) {
            {
              type: :formatted,
              formatted_mode: "advanced",
              expression_reguliere: "/coucou/",
              expression_reguliere_error_message: "certainement pas",
            }
          }

          it { is_expected.to be_falsey }
          it 'has specific error message defined' do
            subject
            expect(champ.errors.full_messages_for(:value).first).to eq "certainement pas"
          end
        end

        context 'without expression reguliere error message defined' do
          let(:tdc_definition) {
            {
              type: :formatted,
              formatted_mode: "advanced",
              expression_reguliere: "/coucou/",
            }
          }

          it 'has default error message' do
            subject
            expect(champ.errors.full_messages_for(:value).first).to eq "n’est pas valide"
          end
        end
      end
    end
  end
end
