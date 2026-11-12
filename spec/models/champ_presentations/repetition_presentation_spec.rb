# frozen_string_literal: true

describe ChampPresentations::RepetitionPresentation do
  let(:libelle) { "Langages de programmation" }
  let(:procedure) {
    create(:procedure, public_type_de_champs: [
      {
        type: :repetition,
        children: [
          { type: :text, libelle: "nom" },
          { type: :integer_number, libelle: "stars" },
        ],
      },
    ])
  }

  let(:dossier) { create(:dossier, procedure:) }
  let(:champ_repetition) { dossier.public_root_champs.first }

  before do
    champ_repetition.add_row(updated_by: 'test')
    champ_repetition.add_row(updated_by: 'test')
    row1, row2, row3 = champ_repetition.rows

    nom, stars = row1.flat_children
    champ_for_update(nom).update(value: "ruby")
    champ_for_update(stars).update(value: 5)

    nom = row2.flat_children.first
    champ_for_update(nom).update(value: "js")

    nom, stars = row3.flat_children
    champ_for_update(nom).update(value: "rust")
    champ_for_update(stars).update(value: 4)
  end

  let(:representation) { described_class.new(libelle, champ_repetition.rows) }

  describe '#to_s' do
    it 'returns a key-value representation' do
      expect(representation.to_s).to eq(
        <<~TXT.strip
          Langages de programmation

          nom : ruby
          stars : 5

          nom : js
          stars :#{' '}

          nom : rust
          stars : 4
        TXT
      )
    end
  end

  describe '#to_tiptap_node' do
    it 'returns the correct HTML structure, without libelle' do
      expected_node = {
        type: "orderedList",
        attrs: { class: "tdc-repetition" },
        content: [
          {
            type: "listItem",
            content: [
              {
                type: "descriptionList",
                content: [
                  { content: [{ text: "nom", type: "text" }], type: "descriptionTerm" },
                  { content: [{ text: "ruby", type: "text" }], type: "descriptionDetails" },
                  { content: [{ text: "stars", type: "text" }], type: "descriptionTerm" },
                  { content: [{ text: "5", type: "text" }], type: "descriptionDetails" },
                ],
              },
            ],
          },
          {
            type: "listItem",
            content: [
              {
                type: "descriptionList",
                content: [
                  { content: [{ text: "nom", type: "text" }], type: "descriptionTerm" },
                  { content: [{ text: "js", type: "text" }], type: "descriptionDetails" },
                  { content: [{ text: "stars", type: "text" }], type: "descriptionTerm", attrs: { class: "invisible" } },
                  { content: [{ text: "", type: "text" }], type: "descriptionDetails" },
                ],
              },
            ],
          },
          {
            type: "listItem",
            content: [
              {
                type: "descriptionList",
                content: [
                  { content: [{ text: "nom", type: "text" }], type: "descriptionTerm" },
                  { content: [{ text: "rust", type: "text" }], type: "descriptionDetails" },
                  { content: [{ text: "stars", type: "text" }], type: "descriptionTerm" },
                  { content: [{ text: "4", type: "text" }], type: "descriptionDetails" },
                ],
              },
            ],
          },
        ],
      }

      expect(representation.to_tiptap_node).to eq(expected_node)
    end

    it 'reads the <br> a champ value carries as a line' do
      champ = double(libelle: 'Adresse', to_s: '12 rue X<br>75001 Paris', blank?: false)
      node = described_class.new(libelle, [double(flat_children: [champ])]).to_tiptap_node

      expect(node[:content].first[:content].first[:content].second).to eq({
        type: "descriptionDetails",
        content: [{ type: 'text', text: '12 rue X' }, { type: 'hardBreak' }, { type: 'text', text: '75001 Paris' }],
      })
    end
  end
end
