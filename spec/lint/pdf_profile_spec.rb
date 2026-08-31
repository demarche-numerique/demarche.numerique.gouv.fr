# frozen_string_literal: true

# Renders a representative corpus of every document family we send to the PDF
# renderer and checks the output against config/pdf_profile.yml (see that file
# for the rationale). Run with PDF_PROFILE_DUMP=1 to (re)write the harvested
# corpus into spec/fixtures/pdf_profile/.
describe 'PDF HTML print profile' do
  let(:profile) { YAML.safe_load_file(Rails.root.join('config/pdf_profile.yml')) }

  # --- corpus ---------------------------------------------------------------

  # Admin-authored TipTap body exercising every node type and mark the editor
  # or a ChampPresentation can emit. TiptapService#to_html is the only
  # producer of admin HTML, so this corpus is exhaustive by construction.
  def all_nodes_json
    {
      type: 'doc',
      content: [
        {
          type: 'header',
          content: [
            { type: 'headerColumn', attrs: { textAlign: 'left' }, content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Colonne gauche' }] }] },
            { type: 'headerColumn', attrs: { textAlign: 'right' }, content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Colonne droite' }] }] },
          ],
        },
        { type: 'title', attrs: { textAlign: 'center' }, content: [{ type: 'text', text: 'Attestation pour le dossier ' }, { type: 'mention', attrs: { id: 'dossier_number', label: 'numéro du dossier' } }] },
        { type: 'heading', attrs: { level: 2, textAlign: 'left' }, content: [{ type: 'text', text: 'Sous-titre' }] },
        { type: 'heading', attrs: { level: 3 }, content: [{ type: 'text', text: 'Sous-sous-titre' }] },
        {
          type: 'paragraph',
          attrs: { textAlign: 'justify' },
          content: [
            { type: 'text', text: 'gras', marks: [{ type: 'bold' }] },
            { type: 'text', text: ' italique', marks: [{ type: 'italic' }] },
            { type: 'text', text: ' souligné', marks: [{ type: 'underline' }] },
            { type: 'text', text: ' surligné', marks: [{ type: 'highlight' }] },
            { type: 'text', text: ' lien', marks: [{ type: 'link', attrs: { href: 'https://exemple.gouv.fr' } }] },
            { type: 'hardBreak' },
            { type: 'text', text: 'après saut de ligne' },
          ],
        },
        { type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'une puce' }] }] }] },
        { type: 'orderedList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'une entrée numérotée' }] }] }] },
        { type: 'paragraph', content: [{ type: 'text', text: 'Choix : ' }, { type: 'mention', attrs: { id: 'champ_liste', label: 'liste' } }] },
        { type: 'paragraph', content: [{ type: 'text', text: 'Bloc répétable : ' }, { type: 'mention', attrs: { id: 'champ_repetition', label: 'répétition' } }] },
        { type: 'pageBreak' },
        { type: 'paragraph', content: [{ type: 'text', text: 'Sur la page suivante.' }] },
        { type: 'footer', attrs: { textAlign: 'center' }, content: [{ type: 'text', text: 'Pied de page' }] },
      ],
    }
  end

  def tiptap_substitutions
    {
      'dossier_number' => '42',
      'champ_liste' => ChampPresentations::MultipleDropDownListPresentation.new(['Premier choix', 'Deuxième choix']),
      'champ_repetition' => ChampPresentations::RepetitionPresentation.new(
        'Personnes',
        [[fake_champ('Nom', 'Dupont'), fake_champ('Prénom', nil)]]
      ),
    }
  end

  # Champ-like object for RepetitionPresentation (libelle / to_s / blank?).
  def fake_champ(libelle, value)
    double(libelle:, to_s: value.to_s, blank?: value.blank?)
  end

  def render_attestation_v2(attestation_template, signature: nil)
    body = TiptapService.new(hard_break: '<br><br>').to_html(all_nodes_json, tiptap_substitutions)

    ApplicationController.render(
      template: '/administrateurs/attestation_template_v2s/show',
      formats: [:html],
      layout: 'attestation',
      assigns: { attestation_template:, body:, signature: }
    )
  end

  def dossier_vide_html(revision)
    ApplicationController.render(
      Dossiers::DossierVidePdfComponent.new(revision:),
      layout: 'dossier_vide_pdf',
      formats: [:html]
    )
  end

  # --- profile check --------------------------------------------------------

  def check_profile!(name, html)
    dump_fixture(name, html) if ENV['PDF_PROFILE_DUMP'] == '1'

    violations = collect_violations(Nokogiri::HTML5(html))

    expect(violations).to be_empty, lambda {
      "#{name}: rendered HTML strays outside config/pdf_profile.yml:\n  - #{violations.join("\n  - ")}"
    }
  end

  def collect_violations(doc)
    violations = []

    doc.root.traverse do |node|
      next unless node.element?

      allowed_attributes = profile['elements'][node.name]

      if allowed_attributes.nil?
        violations << "element <#{node.name}>"
        next
      end

      node.attribute_nodes.each do |attribute|
        violations.concat(attribute_violations(node, attribute, allowed_attributes))
      end
    end

    violations.uniq
  end

  def attribute_violations(node, attribute, allowed_attributes)
    violations = []
    violations << "attribute #{attribute.name} on <#{node.name}>" unless allowed_attributes.include?(attribute.name)

    case attribute.name
    when 'class'
      (attribute.value.split - profile['classes']).each { violations << "class .#{it} (on <#{node.name}>)" }
    when 'style'
      violations.concat(style_violations(attribute.value))
    end

    violations
  end

  def style_violations(style)
    style.split(';').map(&:strip).compact_blank.filter_map do |declaration|
      property, value = declaration.split(':', 2).map(&:strip)
      allowed_values = profile['inline_styles'][property]

      if allowed_values.nil?
        "inline style property #{property}"
      elsif !allowed_values.include?(value)
        "inline style #{property}: #{value}"
      end
    end
  end

  def dump_fixture(name, html)
    normalized = html.gsub(/dcterms\.created" content="[^"]*"/, 'dcterms.created" content="(harvest)"')
    Rails.root.join("spec/fixtures/pdf_profile/#{name}.html").write(normalized)
  end

  # --- the corpus stays within the profile ----------------------------------

  it 'attestation v2 with every TipTap node type and mark' do
    attestation_template = FactoryBot.build(:attestation_template, :v2, label_direction: 'Direction des services', footer: 'Mairie de Bordeaux')

    check_profile!('attestation_v2', render_attestation_v2(attestation_template))
  end

  it 'attestation v2 layout variants (co-émetteur logo, free layout, signature)' do
    official = FactoryBot.create(:attestation_template, :v2, :with_files)
    check_profile!('attestation_v2_co_emetteur', render_attestation_v2(official, signature: official.signature))

    free_layout = FactoryBot.create(:attestation_template, :v2, :with_files, official_layout: false)
    check_profile!('attestation_v2_free_layout', render_attestation_v2(free_layout))
  end

  it 'attestation de dépôt' do
    stub_const('DIRECTION_LABEL', 'Direction interministérielle du numérique')

    html = ApplicationController.render(
      template: 'users/dossiers/attestation_depot',
      formats: [:html],
      layout: 'attestation',
      assigns: { dossier: dossiers.en_construction }
    )

    check_profile!('attestation_depot', html)
  end

  describe 'dossier vide' do
    before_all { seed "cases/champs" }

    it 'with every champ type, a conditional champ with description and an annex' do
      revision = procedures.tous_champs.draft_revision

      # A condition and a description, so the corpus exercises the
      # champ--conditional and description patterns.
      source = revision.type_de_champs.find { it.libelle == 'simple_drop_down_list' && !it.private? }
      target = revision.type_de_champs.find { it.libelle == 'text' && !it.private? }
      target.update!(
        condition: Logic::Eq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('val1')),
        description: 'Une description du champ, avec un lien https://exemple.gouv.fr'
      )

      # A long list, so the corpus exercises the annex pattern.
      revision.add_type_de_champ(
        type_champ: TypeDeChamp.type_champs.fetch(:drop_down_list),
        libelle: 'Grande liste',
        drop_down_options: (1..(Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE + 5)).map { "Option #{it}" }
      )

      check_profile!('dossier_vide', dossier_vide_html(revision.reload))
    end
  end
end
