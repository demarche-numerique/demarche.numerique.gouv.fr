# frozen_string_literal: true

require 'rails_helper'

describe EditableChamp::ReferentielDisplayComponent, type: :component do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:types_de_champ_public) { [{ type: :referentiel, referentiel:, referentiel_mapping: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { (dossier.root_public_champs).first }

  let(:referentiel_mapping) { {} }
  subject { render_inline(described_class.new(champ:)) }

  describe 'renders items' do
    before { champ.update_column(:value_json, { "$.string" => "string", "$.integer" => 42 }) }
    let(:types) { Referentiels::MappingFormComponent::TYPES }
    let(:referentiel_mapping) do
      {
        "$.string" => { libelle: "Libellé string", display_usager: "1", type: types[:string] },
        "$.integer" => { display_usager: "1", type: types[:integer_number] }, # pas de libellé, fallback sur jsonpath
      }
    end

    it 'render pairs' do
      # check libelles
      expect(subject).to have_content("Libellé string")
      expect(subject).to have_content("$.integer")
      # check values
      expect(subject).to have_content("string")
      expect(subject).to have_content("42")
      # check html accessibility
      expect(subject).to have_selector("dl", count: 1)
      expect(subject).to have_selector("dt", count: 2)
      expect(subject).to have_selector("dd", count: 2)
    end
    describe 'renders date and datetime items' do
      before do
        champ.update_column(:value_json, { "$.date" => "14/06/2024", "$.datetime" => "2024-06-19T15:30" })
      end
      let(:referentiel_mapping) do
        {
          "$.date" => { libelle: "Date de naissance", display_usager: "1", type: types[:date] },
          "$.datetime" => { libelle: "Date et heure de naissance", display_usager: "1", type: types[:datetime] },
        }
      end

      it 'render date/time well' do
        expect(subject).to have_content("Date de naissance")
        expect(subject).to have_content("14/06/2024")
        expect(subject).to have_content("Date et heure de naissance")
        expect(subject).to have_content("19 juin 2024 à 15:30")
      end
    end
    describe 'renders boolean items' do
      before do
        champ.update_column(:value_json, { "$.bool_true" => true, "$.bool_false" => false })
      end
      let(:referentiel_mapping) do
        {
          "$.bool_true" => { libelle: "Accepté", display_usager: "1", type: types[:boolean] },
          "$.bool_false" => { libelle: "Refusé", display_usager: "1", type: types[:boolean] },
        }
      end

      it 'render booleans as Oui/Non' do
        expect(subject).to have_content("Accepté")
        expect(subject).to have_content("Oui")
        expect(subject).to have_content("Refusé")
        expect(subject).to have_content("Non")
      end
    end
    describe 'renders list items' do
      before do
        champ.update_column(:value_json, { "$.list" => ["Option 1", nil, "Option 3"] })
      end
      let(:referentiel_mapping) do
        {
          "$.list" => { libelle: "Liste de choix", display_usager: "1", type: types[:array] },
        }
      end

      it 'render lists as comma separated values' do
        expect(subject).to have_content("Liste de choix")
        expect(subject).to have_content("Option 1, Option 3")
      end
    end
    describe 'renders XSS safely' do
      before do
        champ.update_column(:value_json, { "$.xss" => '<script>alert("xss")</script>' })
      end
      let(:referentiel_mapping) do
        {
          "$.xss" => { libelle: "Champ potentiellement dangereux", display_usager: "1", type: types[:string] },
        }
      end

      it 'does not render raw HTML or execute scripts' do
        expect(subject).to have_content("Champ potentiellement dangereux")
        expect(subject).to have_content('<script>alert("xss")</script>')
      end
    end
  end
end
