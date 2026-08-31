# frozen_string_literal: true

require 'open3'

describe DossierVidePayload do
  subject(:payload) { described_class.new(procedure.active_revision).to_h }

  let(:champs) { payload[:champs] }

  def champ(libelle) = champs.find { it[:libelle] == libelle }

  describe 'header and identity' do
    context 'procedure for a legal entity' do
      let(:procedure) { create(:procedure, :published, libelle: 'Ma démarche', for_individual: false) }

      it 'pins the document language to French whatever the UI locale' do
        I18n.with_locale(:en) do
          expect(described_class.new(procedure.active_revision).to_h[:lang]).to eq('fr')
        end
      end

      it 'carries the title, logo and establishment identity' do
        expect(payload[:title]).to eq('Ma démarche')
        expect(payload[:logo][:alt]).to be_present
        expect(Rails.root.join(payload[:logo][:path].delete_prefix('/'))).to be_exist
        expect(payload[:identity_fields]).to include('SIRET')
      end
    end

    context 'procedure for an individual' do
      let(:procedure) { create(:procedure, :published, for_individual: true) }

      it 'carries the individual identity' do
        expect(payload[:identity_fields]).to include('Nom', 'Prénom')
        expect(payload[:identity_fields]).not_to include('SIRET')
      end
    end
  end

  describe 'mailing instruction' do
    context 'with a service' do
      let(:service) { create(:service, nom: 'DDT du Rhône', adresse: "12 rue de la Paix\n69000 Lyon") }
      let(:procedure) { create(:procedure, :published, service:) }

      it 'tells where to send the form on a single line' do
        expect(payload[:mailing]).to eq('À envoyer à DDT du Rhône - 12 rue de la Paix 69000 Lyon')
      end
    end

    context 'without a service' do
      let(:procedure) { create(:procedure, :published, service: nil) }

      it { expect(payload[:mailing]).to be_nil }
    end
  end

  describe 'conditional champ' do
    let(:public_type_de_champs) do
      [
        { type: :drop_down_list, libelle: 'Choix simple', options: ['Fromage', 'Dessert'] },
        { type: :text, libelle: 'Précisez' },
      ]
    end
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:source) { procedure.active_revision.type_de_champs.find { it.libelle == 'Choix simple' } }
    let(:target) { procedure.active_revision.type_de_champs.find { it.libelle == 'Précisez' } }

    def set_condition(condition) = target.update!(condition:)

    context 'with an equality condition' do
      before { set_condition(Logic::Eq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('Dessert'))) }

      it 'humanizes the instruction and marks only the conditional champ' do
        expect(champ('Précisez')[:condition]).to eq('À remplir si « Choix simple » égal à « Dessert »')
        expect(champs.map { it[:conditional] }).to eq([false, true])
      end
    end

    context 'with a negated condition' do
      before { set_condition(Logic::NotEq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('Fromage'))) }

      it { expect(champ('Précisez')[:condition]).to eq('À remplir si « Choix simple » n’est pas « Fromage »') }
    end

    context 'with a composed OR condition' do
      before do
        set_condition(Logic::Or.new([
          Logic::Eq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('Dessert')),
          Logic::Eq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('Fromage')),
        ]))
      end

      it { expect(champ('Précisez')[:condition]).to eq('À remplir si « Choix simple » égal à « Dessert » ou « Choix simple » égal à « Fromage »') }
    end

    context 'without a condition' do
      it 'carries no instruction and no conditional flag' do
        expect(champs.map { it[:condition] }).to all(be_nil)
        expect(champs.map { it[:conditional] }).to all(be(false))
      end
    end

    context 'with an unfinished condition (empty operator)' do
      before { set_condition(Logic::EmptyOperator.new(Logic::Empty.new, Logic::Empty.new)) }

      it 'ignores it entirely' do
        expect(champ('Précisez')[:condition]).to be_nil
        expect(champ('Précisez')[:conditional]).to be(false)
      end
    end
  end

  describe 'admin rich text (Markdown rendered like the web form)' do
    let(:procedure) { create(:procedure, :published, description: 'Présentation en **valorisée**', public_type_de_champs:) }

    def text(string) = { type: 'text', text: string }

    context 'formatting' do
      let(:public_type_de_champs) do
        [
          { type: :text, libelle: 'Nom', description: "Consigne en <b>appuyée</b>\n- point 1\n- point 2" },
          { type: :explication, libelle: 'Infos', description: "Détail _en italique_ et <u>souligné</u>\n# Titre" },
        ]
      end

      it 'renders Markdown emphasis in the procedure presentation' do
        expect(payload[:presentation]).to eq([
          { type: 'paragraph', content: [text('Présentation en '), { type: 'strong', content: [text('valorisée')] }] },
        ])
      end

      it 'renders inline HTML and lists in champ descriptions' do
        expect(champ('Nom')[:description]).to eq([
          { type: 'paragraph', content: [text('Consigne en '), { type: 'strong', content: [text('appuyée')] }] },
          { type: 'list', ordered: false, start: 1, items: [[text('point 1')], [text('point 2')]] },
        ])
      end

      it 'renders emphasis and turns authored headings into bold paragraphs' do
        expect(champ('Infos')[:text]).to eq([
          { type: 'paragraph', content: [text('Détail '), { type: 'emph', content: [text('en italique')] }, text(' et '), { type: 'underline', content: [text('souligné')] }] },
          { type: 'paragraph', content: [{ type: 'strong', content: [text('Titre')] }] },
        ])
      end
    end

    context 'ordered list' do
      let(:public_type_de_champs) do
        [{ type: :text, libelle: 'Nom', description: "3. trois\n4. quatre" }]
      end

      it 'keeps the authored numbering' do
        expect(champ('Nom')[:description]).to eq([
          { type: 'list', ordered: true, start: 3, items: [[text('trois')], [text('quatre')]] },
        ])
      end
    end

    context 'links' do
      let(:public_type_de_champs) do
        [{ type: :text, libelle: 'Nom', description: 'Voir [le guide](https://exemple.fr/guide) avant, ou <a href="https://exemple.fr/faq">la FAQ</a>.' }]
      end

      it 'links the label and spells out the target' do
        expect(champ('Nom')[:description]).to eq([
          {
            type: 'paragraph',
            content: [
              text('Voir '),
              { type: 'link', href: 'https://exemple.fr/guide', content: [text('le guide')], spell: 'https://exemple.fr/guide' },
              text(' avant, ou '),
              { type: 'link', href: 'https://exemple.fr/faq', content: [text('la FAQ')], spell: 'https://exemple.fr/faq' },
              text('.'),
            ],
          },
        ])
      end
    end

    context 'link labeled by its own URL, bare URL and email' do
      let(:public_type_de_champs) do
        [{ type: :text, libelle: 'Nom', description: '<a href="https://exemple.fr">https://exemple.fr</a> ou https://exemple.fr/aide ou aide@exemple.fr' }]
      end

      it 'keeps URLs as plain text (linked by the template) and links the email once' do
        expect(champ('Nom')[:description]).to eq([
          {
            type: 'paragraph',
            content: [
              text('https://exemple.fr'),
              text(' ou '),
              text('https://exemple.fr/aide'),
              text(' ou '),
              { type: 'link', href: 'mailto:aide@exemple.fr', content: [text('aide@exemple.fr')], spell: nil },
            ],
          },
        ])
      end
    end

    context 'authored line breaks' do
      let(:public_type_de_champs) do
        [{ type: :text, libelle: 'Nom', description: "Ligne 1\nLigne 2\n\nLigne 3<br>Ligne 4" }]
      end

      it 'keeps them as separate paragraphs and explicit breaks, like the web' do
        expect(champ('Nom')[:description]).to eq([
          { type: 'paragraph', content: [text('Ligne 1')] },
          { type: 'paragraph', content: [text('Ligne 2')] },
          { type: 'paragraph', content: [text('Ligne 3'), { type: 'linebreak' }, text('Ligne 4')] },
        ])
      end
    end

    context 'blank or tag-only text' do
      let(:public_type_de_champs) do
        [{ type: :text, libelle: 'Nom', description: "<script>alert(1)</script> <b></b>\n \n" }]
      end

      it 'keeps only the sanitized text, or nothing' do
        expect(champ('Nom')[:description]).to eq([{ type: 'paragraph', content: [text('alert(1)')] }])
        expect(payload[:champs].sole[:condition]).to be_nil
      end
    end
  end

  describe 'dispatch per champ type' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }

    context 'header_section' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, libelle: 'Niveau 1', level: 1 },
          { type: :header_section, libelle: 'Niveau 2', level: 2 },
          { type: :header_section, libelle: 'Niveau 3', level: 3 },
        ]
      end

      it 'maps each section level to a heading below the h2 form title' do
        expect(champs.map { it.slice(:type, :level) })
          .to eq([{ type: 'heading', level: 3 }, { type: 'heading', level: 4 }, { type: 'heading', level: 5 }])
      end
    end

    context 'header_section without a title' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, libelle: 'Sans titre', level: 1, description: 'Consignes de la section' },
          { type: :header_section, libelle: 'Suite', level: 1 },
        ]
      end

      # (a blank libelle is only defaulted when the type changes: an admin can clear it afterwards)
      before { procedure.active_revision.type_de_champs.find { it.libelle == 'Sans titre' }.update!(libelle: '') }

      # typst rejects an empty heading title under PDF/UA-1: the section keeps
      # its description only, and does not count as a heading for the clamp.
      it 'emits no heading, keeps the description, and does not shift the following levels' do
        expect(payload[:champs].first).to include(type: 'heading', level: nil, text: nil, description: [{ type: 'paragraph', content: [{ type: 'text', text: 'Consignes de la section' }] }])
        expect(payload[:champs].second).to include(type: 'heading', level: 3, text: 'Suite')
      end
    end

    context 'header_section levels with a gap (revision predating the consistency validator)' do
      let(:public_type_de_champs) do
        [
          { type: :header_section, libelle: 'Profond', level: 2 },
          { type: :header_section, libelle: 'Suite', level: 3 },
        ]
      end

      it 'clamps headings to consecutive levels, as PDF/UA-1 requires' do
        expect(champs.map { it[:level] }).to eq([3, 4])
      end
    end

    context 'yes_no' do
      let(:public_type_de_champs) { [{ type: :yes_no, libelle: 'D’accord ?' }] }

      it 'carries two Oui/Non options and the check instruction' do
        expect(champ('D’accord ?')[:options]).to eq([{ label: 'Oui' }, { label: 'Non' }])
        expect(champ('D’accord ?')[:explanation]).to eq('Cochez la mention applicable')
      end
    end

    context 'civilite' do
      let(:public_type_de_champs) { [{ type: :civilite, libelle: 'Civilité' }] }

      it { expect(champ('Civilité')[:options].size).to eq(2) }
    end

    context 'simple drop_down_list' do
      let(:public_type_de_champs) do
        [{ type: :drop_down_list, libelle: 'Choix', options: ['A', 'B', 'C'] }]
      end

      it 'carries the options and the single-value instruction' do
        expect(champ('Choix')[:options]).to eq([{ label: 'A' }, { label: 'B' }, { label: 'C' }])
        expect(champ('Choix')[:explanation]).to eq('Cochez la mention applicable, une seule valeur possible')
      end
    end

    context 'drop_down_list with too many options' do
      let(:options) { (1..Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE).map { |i| "Option #{i}" } }
      let(:public_type_de_champs) do
        [{ type: :drop_down_list, libelle: 'Choix', options: }]
      end

      it 'falls back to a fillable box referencing the annex' do
        expect(champ('Choix')[:type]).to eq('box')
        expect(champ('Choix')[:explanation])
          .to eq('La liste complète des options figure en Annexe 1. Renseignez la mention applicable, une seule valeur possible')
      end

      it 'lists every option in the annex' do
        expect(payload[:annexes]).to eq([{ title: 'Annexe 1 : Choix', options: }])
      end
    end

    context 'multiple_drop_down_list with too many options' do
      let(:options) { (1..Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE).map { |i| "Option #{i}" } }
      let(:public_type_de_champs) do
        [{ type: :multiple_drop_down_list, libelle: 'Choix', options: }]
      end

      it 'references the annex with the multiple-values instruction' do
        expect(champ('Choix')[:type]).to eq('box')
        expect(champ('Choix')[:explanation])
          .to eq('La liste complète des options figure en Annexe 1. Renseignez les mentions applicables, plusieurs valeurs possibles')
        expect(payload[:annexes].sole[:options].size).to eq(options.size)
      end
    end

    context 'list too large to print' do
      let(:online_url) { Rails.application.routes.url_helpers.commencer_url(procedure.path) }

      before { stub_const('DossierVidePayload::MAX_PRINTABLE_OPTIONS', 3) }

      let(:public_type_de_champs) do
        [{ type: :drop_down_list, libelle: 'Commune', options: ['Lyon', 'Paris', 'Rennes', 'Toulouse'] }]
      end

      it 'refers to the online form instead of printing the list or an annex' do
        expect(champ('Commune')[:type]).to eq('box')
        expect(champ('Commune')[:explanation]).to include('4 valeurs', online_url)
        expect(payload[:annexes]).to be_empty
      end
    end

    context 'linked_drop_down_list small enough to print' do
      let(:public_type_de_champs) do
        [{ type: :linked_drop_down_list, libelle: 'Lieu', options: ['--Rhône--', 'Lyon', 'Villeurbanne'] }]
      end

      it 'lists every level with the secondary flag' do
        expect(champ('Lieu')[:options]).to eq([
          { label: 'Rhône' },
          { label: 'Lyon', secondary: true },
          { label: 'Villeurbanne', secondary: true },
        ])
      end
    end

    context 'several champs with too many options' do
      let(:options) { (1..Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE).map { |i| "Option #{i}" } }
      let(:public_type_de_champs) do
        [
          { type: :drop_down_list, libelle: 'Premier', options: },
          { type: :multiple_drop_down_list, libelle: 'Second', options: },
        ]
      end

      it 'numbers the annexes in document order' do
        expect(payload[:annexes].map { it[:title] }).to eq(['Annexe 1 : Premier', 'Annexe 2 : Second'])
      end
    end

    context 'piece_justificative' do
      let(:public_type_de_champs) { [{ type: :piece_justificative, libelle: 'RIB' }] }

      it 'carries the libelle as the checkbox label' do
        expect(champs.sole).to include(type: 'piece_justificative', option: 'RIB')
      end
    end

    context 'repetition' do
      let(:public_type_de_champs) do
        [{ type: :repetition, libelle: 'Personnes', children: [{ type: :text, libelle: 'Nom' }] }]
      end

      it 'carries 3 occurrences of the child champ' do
        occurrences = champ('Personnes')[:occurrences]
        expect(occurrences.size).to eq(3)
        expect(occurrences).to all(match([hash_including(libelle: 'Nom', type: 'box')]))
      end
    end

    context 'default text champ' do
      let(:public_type_de_champs) { [{ type: :text, libelle: 'Votre nom' }] }

      it 'carries a label and a fillable box' do
        expect(champs.sole).to include(type: 'box', libelle: 'Votre nom', box: 'block')
      end
    end
  end

  describe 'PDF rendering' do
    before_all { seed "cases/champs" }

    let(:revision) { procedures.tous_champs.draft_revision }
    let(:payload) { described_class.new(revision.reload).to_h }

    before do
      source = revision.type_de_champs.find { it.libelle == 'simple_drop_down_list' && !it.private? }
      target = revision.type_de_champs.find { it.libelle == 'text' && !it.private? }
      target.update!(
        condition: Logic::Eq.new(Logic::ChampValue.new(source.stable_id), Logic::Constant.new('val1')),
        description: "Voir [le guide](https://exemple.fr/guide) et **important**\n- point 1\n- point 2\n\n3. trois\n\nLigne 1<br>Ligne 2 aide@exemple.fr"
      )
      revision.add_type_de_champ(type_champ: TypeDeChamp.type_champs.fetch(:header_section), libelle: 'Sans titre', description: 'Section sans titre')
        .update!(libelle: '')
      revision.add_type_de_champ(
        type_champ: TypeDeChamp.type_champs.fetch(:drop_down_list),
        libelle: 'Grande liste',
        drop_down_options: (1..(Champs::DropDownListChamp::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE + 5)).map { "Option #{it}" }
      )
    end

    it 'lays out the form structure: headings, annex, rendered Markdown', :external_deps do
      require_tool!('typst')

      document = TypstService.query('dossier_vide', payload, '(headings: headings(), links: links(), lists: lists(), enums: enums(), paragraphs: paragraphs())')

      expect(document['headings'].first).to eq('level' => 1, 'text' => revision.procedure.libelle)
      expect(document['headings'].filter { it['level'] == 2 }.map { it['text'] }).to eq(['Identité du demandeur', 'Formulaire', 'Annexes'])
      expect(document['headings']).to include('level' => 3, 'text' => 'Annexe 1 : Grande liste')
      expect(document['headings'].map { it['text'] }).not_to include('')
      expect(document['paragraphs']).to include('Section sans titre')
      expect(document['links']).to include(
        { 'dest' => 'https://exemple.fr/guide', 'text' => 'le guide' },
        { 'dest' => 'https://exemple.fr/guide', 'text' => 'https://exemple.fr/guide' }, # spelled-out copy, linked by the URL show rule
        { 'dest' => 'mailto:aide@exemple.fr', 'text' => 'aide@exemple.fr' }
      )
      expect(document['lists']).to include(['point 1', 'point 2'])
      expect(document['enums']).to include('start' => 3, 'items' => ['trois'])
      expect(document['paragraphs']).to include('Voir le guide (https://exemple.fr/guide) et important', "Ligne 1\nLigne 2 aide@exemple.fr")
    end

    it 'renders a PDF that passes veraPDF PDF/UA-1 validation', :external_deps do
      require_tool!('typst')

      pdf = TypstService.generate_pdf('dossier_vide', payload)

      expect(pdf[0, 5]).to eq('%PDF-')

      require_tool!('verapdf')

      Tempfile.create(['dossier_vide', '.pdf']) do |file|
        file.binmode
        file.write(pdf)
        file.flush

        report, warnings, = Open3.capture3('verapdf', '--format', 'text', '--flavour', 'ua1', file.path)

        expect(report).to start_with('PASS'), -> { "veraPDF PDF/UA-1 validation failed:\n#{report}\n#{warnings}" }
      end
    end
  end
end
