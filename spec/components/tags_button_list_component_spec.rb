# frozen_string_literal: true

RSpec.describe TagsButtonListComponent, type: :component do
  let(:tags) do
    {
      individual: TagsSubstitutionConcern::INDIVIDUAL_TAGS,
      etablissement: TagsSubstitutionConcern::ENTREPRISE_TAGS,
      dossier: TagsSubstitutionConcern::DOSSIER_TAGS,
      champ_public: [
        {
          id: 'tdc12',
          libelle: 'Votre avis',
          description: 'Détaillez votre avis',
          mandatory: true,
          conditional: false,
        },
        {
          id: 'tdc13',
          libelle: 'Un champ facultatif',
          description: 'Ce champ est facultatif',
          mandatory: false,
          conditional: false,
        },
        {
          id: 'tdc14',
          libelle: 'Un champ conditionnel',
          description: 'Ce champ est conditionnel',
          mandatory: false,
          conditional: true,
        },
        {
          id: 'tdc15',
          libelle: 'Un champ obligatoire conditionnel',
          description: '',
          mandatory: true,
          conditional: true,
        },
        {
          id: 'tdc16',
          libelle: 'Une répétition',
          description: '',
          mandatory: true,
          conditional: false,
          block: true,
        },
      ],

      champ_private: [
        {
          id: 'tdc22',
          libelle: 'Montant accordé',
        },
      ],
    }
  end

  let(:component) do
    described_class.new(tags:)
  end

  subject { render_inline(component).to_html }

  it 'renders' do
    expect(subject).to have_text("Identité")
    expect(subject).to have_text("civilité")
    expect(subject).to have_text("Votre avis")
    expect(subject).to have_text("Montant accordé")
  end

  it 'flags the tags rendered as a list for the editor' do
    expect(subject).to have_css("button[data-tag-id='tdc16'][data-tag-block='true']")
    expect(subject).to have_css("button[data-tag-id='dossier_number'][data-tag-block='']")
  end

  it "hides optional and conditional tags by default" do
    expect(subject).to have_selector(".hidden button.fr-tag", text: "Un champ facultatif")
    expect(subject).to have_selector(".hidden button.fr-tag", text: "Un champ conditionnel")
    expect(subject).to have_selector(".hidden button.fr-tag", text: "Un champ obligatoire conditionnel")
    expect(subject).to have_selector(":not(.hidden) button.fr-tag", text: "Votre avis")
    expect(subject).to have_text("Voir les champs facultatifs et/ou conditionnés")
  end

  it "wires the optional toggle to its own controller, with a unique per-instance id" do
    fragment = Nokogiri::HTML.fragment(render_inline(component).to_html)
    checkbox = fragment.at_css("input[type='checkbox']")
    expect(checkbox["data-action"]).to eq("change->tags-button-list#toggleOptional")
    expect(fragment.at_css("label")[:for]).to eq(checkbox[:id])

    other_checkbox = Nokogiri::HTML.fragment(render_inline(described_class.new(tags:)).to_html).at_css("input[type='checkbox']")
    expect(other_checkbox[:id]).not_to eq(checkbox[:id])
  end

  it "suffixes mandatory tags with * and conditional tags with [conditionné]" do
    expect(subject).to have_selector("button.fr-tag", text: /\A\s*Votre avis\s+\*\s*\z/)
    expect(subject).to have_selector("button.fr-tag", text: /\A\s*Un champ facultatif\s*\z/)
    expect(subject).to have_selector("button.fr-tag", text: /\A\s*Un champ conditionnel\s+\[conditionné\]\s*\z/)
    expect(subject).to have_selector("button.fr-tag", text: /\A\s*Un champ obligatoire conditionnel\s+\*\s+\[conditionné\]\s*\z/)
  end

  it "applies purple-glycine style to conditional tags only" do
    expect(subject).to have_selector("button.fr-tag.fr-tag--purple-glycine", text: "Un champ conditionnel")
    expect(subject).to have_selector("button.fr-tag.fr-tag--purple-glycine", text: "Un champ obligatoire conditionnel")
    expect(subject).not_to have_selector("button.fr-tag.fr-tag--purple-glycine", text: "Un champ facultatif")
    expect(subject).not_to have_selector("button.fr-tag.fr-tag--purple-glycine", text: "Votre avis")
  end
end
