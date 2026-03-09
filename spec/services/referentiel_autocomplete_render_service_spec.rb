# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReferentielAutocompleteRenderService do
  let(:referentiel) { create(:api_referentiel, :autocomplete, datasource: '$.items') }
  let(:api_response) do
    {
      'items' => [
        { 'finess' => 'Tango', 'ej_rs' => 'Charlie' },
        { 'finess' => 'Bob', 'ej_rs' => 'Delta' },
      ],
    }
  end

  let(:subject) { described_class.new(api_response, referentiel) }

  describe '.format_response' do
    it 'formats the response for autocomplete' do
      expect(subject.format_response).to match_array([
        {
          label: 'Tango (Charlie)',
          value: '0:Tango (Charlie)',
          data: anything,
        },
        {
          label: 'Bob (Delta)',
          value: '1:Bob (Delta)',
          data: anything,
        },
      ])
    end

    context 'with duplicate labels' do
      let(:api_response) do
        {
          'items' => [
            { 'finess' => 'Dupli', 'ej_rs' => 'A' },
            { 'finess' => 'Dupli', 'ej_rs' => 'A' },
          ],
        }
      end

      it 'ensures unique values to prevent infinite loops' do
        result = subject.format_response
        expect(result.map { |item| item[:value] }.uniq.count).to eq(2)
        expect(result.map { |item| item[:value] }).to match_array(['0:Dupli (A)', '1:Dupli (A)'])
      end
    end
  end

  describe '.render_template' do
    it 'generates plain text from the template and the object' do
      obj = {
        'finess' => 'Tango',
        'ej_rs' => "Charlie",
      }
      expect(
        subject.send(:render_template, referentiel.json_template, obj).join('')
      ).to include('Tango (Charlie)')
    end

    context 'with incompatible keys with passwed to JsonPath' do
      it 'works' do
        obj = {
          "Prénom d'exercice" => "SOPHIE",
        }
        referentiel.json_template = {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
                "content" =>
                [
                  { "type" => "mention", "attrs" => { "id" => "$.Prénom d'exercice", "label" => "$.Prénom d'exercice (SOPHIE)" } },
                  { "text" => "  ", "type" => "text" },
                ],
            },
          ],
        }
        expect(
          subject.send(:render_template, referentiel.json_template, obj).join('')
        ).to include('SOPHIE')
      end
    end
  end
end
