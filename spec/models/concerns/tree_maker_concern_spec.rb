# frozen_string_literal: true

RSpec.describe TreeMakerConcern do
  # Renders the tree built by `tree_it` as a nested hash `{ libelle => subtree }`,
  # leaves being `{}`. The shape of the literal then visually mirrors the expected
  # hierarchy.
  def tree_of(nodes)
    nodes.to_h { |node| [node.libelle, tree_of(node.children)] }
  end

  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:revision) { procedure.draft_revision }
  subject(:tree) { tree_of(revision.types_de_champ_public) }

  context 'with well-formed nested sections (levels 1 → 2)' do
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 'Identité' },
        { type: :text,                     libelle: 'Nom' },
        { type: :header_section, level: 2, libelle: 'Adresse' },
        { type: :text,                     libelle: 'Rue' },
        { type: :header_section, level: 1, libelle: 'Pièces' },
        { type: :text,                     libelle: 'Justificatif' },
      ]
    end

    it 'nests each field under its header and closes a section at a same-level header' do
      expect(tree).to eq(
        'Identité' => {
          'Nom' => {},
          'Adresse' => { 'Rue' => {} },
        },
        'Pièces' => { 'Justificatif' => {} }
      )
    end
  end

  context 'with non-monotonic header levels (skip 1 → 3 → 2)' do
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 'A' },
        { type: :header_section, level: 3, libelle: 'C' },
        { type: :header_section, level: 2, libelle: 'B' },
      ]
    end

    it 'closes a section when a shallower header appears (B is a sibling of C, not its child)' do
      expect(tree).to eq(
        'A' => {
          'C' => {},
          'B' => {},
        }
      )
    end
  end

  context 'with a repetition holding a nested section' do
    let(:types_de_champ_public) do
      [
        { type: :text, libelle: 'Nom' },
        {
          type: :repetition, libelle: 'Enfants', children: [
            { type: :text, libelle: 'Prénom' },
            { type: :header_section, level: 1, libelle: 'Détails' },
            { type: :text,                     libelle: 'Âge' },
          ],
        },
      ]
    end

    it 'inlines the repetition members as its children, applying header nesting inside' do
      expect(tree).to eq(
        'Nom' => {},
        'Enfants' => {
          'Prénom' => {},
          'Détails' => { 'Âge' => {} },
        }
      )
    end
  end
end
