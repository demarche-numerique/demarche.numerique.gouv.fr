# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillFormatted do
  let(:procedure) { build(:procedure) }
  let(:type_de_champ) { build(:type_de_champ_formatted, procedure:) }
  let(:champ) { Champs::FormattedChamp.new }

  subject { described_class.new(type_de_champ, procedure.active_revision) }

  describe '#example_value' do
     context 'when mode is advanced' do
       before do
         type_de_champ.options = {
           "formatted_mode" => "advanced",
           "expression_reguliere_exemple_text" => "ABC123",
         }
       end

       it { expect(subject.example_value).to eq("ABC123") }
     end

     context 'when mode is simple' do
       let(:base_options) do
         {
           "formatted_mode" => "simple",
           "letters_accepted" => "0",
           "numbers_accepted" => "0",
           "special_characters_accepted" => "0",
           "min_character_length" => "",
           "max_character_length" => "",
         }
       end

       it 'returns combination of allowed characters' do
         type_de_champ.options = base_options.merge(
           "letters_accepted" => "1",
           "numbers_accepted" => "1",
           "special_characters_accepted" => "1"
         )
         expect(subject.example_value).to match(/[A-Z0-9]/)
       end

       it 'respects minimum length' do
         type_de_champ.options = base_options.merge(
           "letters_accepted" => "1",
           "min_character_length" => "10"
         )
         expect(subject.example_value).to match(/^[A-Z]{10,}$/)
       end

       it 'respects maximum length' do
         type_de_champ.options = base_options.merge(
           "letters_accepted" => "1",
           "numbers_accepted" => "1",
           "min_character_length" => "3",
           "max_character_length" => "4"
         )
         expect(subject.example_value).to match(/^[A-Z0-9]{3,4}$/)
       end

       it 'reasonable length' do
         type_de_champ.options = base_options.merge(
           "letters_accepted" => "1",
           "numbers_accepted" => "1",
           "min_character_length" => "1000",
           "max_character_length" => "200000"
         )
         expect(subject.example_value.size).to eq(100)
       end
     end
   end
end
