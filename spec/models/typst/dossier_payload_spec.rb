# frozen_string_literal: true

require 'open3'

describe Typst::DossierPayload do
  it 'is named after its template' do
    expect(described_class.template).to eq('dossier')
    expect(TypstService::ROOT.join('dossier.typ')).to be_file
  end

  include Logic

  def acls_for(dossier, profile) = PiecesJustificativesService.new(user_profile: profile, export_template: nil).acl_for_dossier_export(dossier.procedure)

  def payload_for(dossier, profile = dossier.user)
    TypstService.with_assets { described_class.new(dossier, acls: acls_for(dossier, profile), assets: it).to_h }
  end

  def block(payload, label) = payload[:form][:champs].find { it[:label] == label }

  def rows(payload, title) = payload[:sections].find { it[:title] == title }[:rows]

  describe 'head, dossier and identity sections' do
    let(:dossier) { dossiers.accepte }
    subject(:payload) { payload_for(dossier) }

    it 'names the document, pins French and carries the letterhead' do
      I18n.with_locale(:en) do
        expect(payload_for(dossier)[:lang]).to eq('fr')
      end
      expect(payload[:title]).to eq("Dossier n° #{dossier.id}")
      expect(payload[:procedure]).to eq(dossier.procedure.libelle)
      expect(payload[:date]).to start_with('Édité le ')
      expect(payload[:logo][:alt]).to be_present
      expect(payload[:draft_warning]).to be_nil
    end

    it 'summarizes the dossier through the dossier columns' do
      expect(rows(payload, 'Dossier')).to include(
        ['État', 'Accepté'],
        ['Motivation de la décision', 'Dossier complet.'],
        ['Date de dépôt', I18n.l(dossier.depose_at, format: :short_with_time)],
        ['Date de traitement', I18n.l(dossier.processed_at, format: :short_with_time)]
      )
      expect(rows(payload, 'Dossier').map(&:first)).not_to include('Correction demandée le')
    end

    it 'lists the individual identity through the individual columns, plus the birthdate' do
      expect(rows(payload, 'Identité du demandeur')).to include(
        ['Adresse électronique', dossier.user_email_for(:display)],
        ['Civilité', 'Mme'],
        ['Nom', 'Dupont'],
        ['Prénom', 'Jeanne'],
        ['Date de naissance', I18n.l(Date.new(1985, 3, 12))]
      )
      expect(rows(payload, 'Identité du demandeur').map(&:first)).not_to include('Dépôt pour un tiers')
    end

    context 'dossier of an etablissement' do
      let(:dossier) { dossiers.entreprise_en_instruction }

      it 'lists the etablissement through the moral columns' do
        identity = rows(payload, 'Identité du demandeur')

        expect(identity).to include(['Établissement SIRET', dossier.etablissement.siret])
        expect(identity.map(&:first)).to include('Entreprise raison sociale', 'Entreprise forme juridique', 'Établissement Adresse')
      end
    end

    context 'dossier of a procedure in test' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'Nom' }]) }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      it 'warns that the dossier can be deleted' do
        expect(payload[:draft_warning]).to include(title: 'Démarche en test', text: include('supprimé à tout moment'))
      end
    end
  end

  describe 'form: values and detail rows through the columns' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :text, libelle: 'Nom' },
        { type: :integer_number, libelle: 'Surface' },
        { type: :yes_no, libelle: 'Propriétaire' },
        { type: :multiple_drop_down_list, libelle: 'Options', options: ['Eau', 'Gaz', 'Électricité'] },
        { type: :address, libelle: 'Adresse' },
        { type: :piece_justificative, libelle: 'Justificatif' },
        { type: :piece_justificative, nature: 'titre_identite', libelle: 'Pièce d’identité' },
        { type: :textarea, libelle: 'Commentaire' },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    subject(:payload) { payload_for(dossier) }

    before do
      champ = -> (libelle) { dossier.root_champs_public.find { it.libelle == libelle } }
      champ.('Surface').update(value: '1234567')
      champ.('Propriétaire').update(value: 'true')
      champ.('Options').update(value: ['Eau', 'Gaz'].to_json)
      champ.('Commentaire').update(value: nil)
      dossier.reload
    end

    it 'formats plain, numeric, boolean and list values' do
      expect(block(payload, 'Nom')).to include(type: 'field', blank: false, details: [])
      expect(block(payload, 'Surface')[:value]).to eq('1 234 567')
      expect(block(payload, 'Propriétaire')[:value]).to eq('Oui')
      expect(block(payload, 'Options')[:value]).to eq('Eau, Gaz')
    end

    it 'adds the detail rows of the other displayable columns, without the libelle prefix' do
      address = block(payload, 'Adresse')

      expect(address[:value]).to be_present
      expect(address[:details].map(&:first)).to include(a_string_starting_with('Code postal'), 'Commune')
    end

    it 'lists the attached files by name and only tells whether an identity document is present' do
      expect(block(payload, 'Justificatif')).to include(type: 'files')
      expect(block(payload, 'Justificatif')[:files]).to all(be_present)
      expect(block(payload, 'Pièce d’identité')[:value]).to eq('présent')
    end

    it 'marks a value the usager did not provide' do
      expect(block(payload, 'Commentaire')).to include(type: 'field', value: 'Non communiqué', blank: true)
    end
  end

  describe 'form: section headings' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: 'Identité', level: 1 },
        { type: :header_section, libelle: 'État civil', level: 2 },
        { type: :text, libelle: 'Nom' },
        { type: :header_section, libelle: 'Détail', level: 3 },
        { type: :text, libelle: 'Prénom' },
        { type: :header_section, libelle: 'Coordonnées', level: 2 },
        { type: :text, libelle: 'Email' },
        { type: :header_section, libelle: 'Justificatifs', level: 1 },
        { type: :explication, libelle: 'Consigne', description: 'Joindre un **scan** lisible.' },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    subject(:headings) { payload_for(dossier)[:form][:champs].filter { it[:type] == 'heading' } }

    it 'numbers the sections hierarchically, one heading level per section level below the h2' do
      expect(headings).to eq([
        { type: 'heading', level: 3, text: '1. Identité' },
        { type: 'heading', level: 4, text: '1.1. État civil' },
        { type: 'heading', level: 5, text: '1.1.1. Détail' },
        { type: 'heading', level: 4, text: '1.2. Coordonnées' },
        { type: 'heading', level: 3, text: '2. Justificatifs' },
      ])
    end

    it 'renders an explication as rich text' do
      explication = block(payload_for(dossier), 'Consigne')

      expect(explication[:type]).to eq('explication')
      expect(explication[:text].first[:content]).to include(type: 'strong', content: [{ type: 'text', text: 'scan' }])
    end
  end

  describe 'form: conditional champs' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :header_section, libelle: 'Parent', level: 1 },
        { type: :integer_number, libelle: 'Critère', stable_id: 99 },
        { type: :header_section, libelle: 'Caché', level: 2, condition: ds_eq(champ_value(99), constant(5)) },
        { type: :text, libelle: 'Optionnel', condition: ds_eq(champ_value(99), constant(5)) },
        { type: :header_section, libelle: 'Visible', level: 2 },
        { type: :text, libelle: 'Toujours' },
      ])
    end
    let(:dossier) do
      create(:dossier, :en_construction, procedure:).tap do |dossier|
        dossier.root_champs_public.find { it.libelle == 'Critère' }.update(value: '1')
        dossier.root_champs_public.find { it.libelle == 'Optionnel' }.update(value: 'saisi puis caché')
        dossier.reload
      end
    end
    let(:instructeur) { create(:instructeur) }

    it 'skips hidden champs and headings, numbering the visible ones' do
      labels = payload_for(dossier)[:form][:champs].map { it[:text] || it[:label] }

      expect(labels).to eq(['1. Parent', 'Critère', '1.1. Visible', 'Toujours'])
    end

    context 'when the usager had filled the champ in the revision they submitted' do
      before { dossier.update_column(:submitted_revision_id, procedure.draft_revision.id) }

      it 'stays hidden to the usager but shows to the instructeur, like the web view' do
        expect(block(payload_for(dossier, dossier.user), 'Optionnel')).to be_nil
        expect(block(payload_for(dossier, instructeur), 'Optionnel')).to include(value: 'saisi puis caché')
      end
    end
  end

  describe 'form: repetition' do
    let(:procedure) do
      create(:procedure, :published, public_type_de_champs: [
        { type: :repetition, libelle: 'Enfant', children: [{ type: :text, libelle: 'Prénom' }, { type: :integer_number, libelle: 'Âge' }] },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

    it 'renders each row as its own group of champs' do
      repetition = block(payload_for(dossier), 'Enfant')

      expect(repetition[:type]).to eq('repetition')
      expect(repetition[:rows].size).to be >= 1
      expect(repetition[:rows].first[:title]).to eq('Enfant 1')
      expect(repetition[:rows].first[:champs].map { it[:label] }).to eq(['Prénom', 'Âge'])
    end
  end

  describe 'form: carte' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :carte, libelle: 'Emprise' }]) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:champ) { dossier.root_champs_public.first }

    before { champ.update(geo_areas: [build(:geo_area, :selection_utilisateur, :polygon)]) }

    it 'lists the geometries when the static map is not rendered yet' do
      carte = block(payload_for(dossier), 'Emprise')

      expect(carte[:type]).to eq('carte')
      expect(carte[:map]).to be_nil
      expect(carte[:areas].size).to eq(1)
      expect(carte[:areas].first[:label]).to be_present
    end

    it 'embeds the static map as an asset with an alt text' do
      champ.attach_static_map(Rails.root.join('spec/fixtures/files/image-no-exif.jpg').open, digest: 'abc')

      TypstService.with_assets do |assets|
        carte = described_class.new(dossier, acls: acls_for(dossier, dossier.user), assets:).to_h[:form][:champs].first

        expect(carte[:map][:alt]).to include('Emprise')
        expect(assets.root.join(carte[:map][:path].delete_prefix('/'))).to be_file
      end
    end
  end

  describe 'form: FranceConnect champ' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :aah, libelle: 'AAH' }]) }
    let(:dossier) do
      create(:dossier, :en_construction, procedure:).tap do |dossier|
        dossier.root_champs_public.first.update(external_state: 'fetched', value: 'true', value_json: { api_part: { est_beneficiaire: true } })
      end
    end

    it 'never prints the raw confirmation flag' do
      aah = payload_for(dossier)[:form][:champs].first

      expect(aah).not_to include(value: 'true')
      expect(aah.to_json).not_to include('"true"')
    end
  end

  describe 'annotations, avis and messagerie per profile' do
    let(:procedure) do
      create(:procedure, :published,
        public_type_de_champs: [{ type: :text, libelle: 'Nom' }],
        private_type_de_champs: [{ type: :header_section, libelle: 'Notes', level: 1 }, { type: :text, libelle: 'Statut' }],
        instructeurs: [instructeur],
        allow_expert_messaging: false)
    end
    let(:instructeur) { create(:instructeur) }
    let(:expert) { create(:expert) }
    let(:experts_procedure) { create(:experts_procedure, expert:, procedure:) }
    let(:dossier) { create(:dossier, :en_instruction, :with_populated_annotations, procedure:) }
    let!(:avis) { create(:avis, dossier:, experts_procedure:, introduction: 'Que pensez-vous de ce dossier ?', question_label: 'Favorable ?') }
    let!(:confidential_avis) { create(:avis, :confidentiel, dossier:, introduction: 'Un autre avis', answer: 'Réservé') }
    let!(:commentaire) { create(:commentaire, dossier:, email: instructeur.email, body: "<p>Bonjour,</p><p>merci &amp; à bientôt</p>") }
    let!(:user_commentaire) { create(:commentaire, dossier:, email: dossier.user.email, body: 'Merci') }

    it 'gives the instructeur the annotations, every avis and the messagerie' do
      payload = payload_for(dossier, instructeur)

      expect(payload[:annotations][:champs].map { it[:text] || it[:label] }).to eq(['1. Notes', 'Statut'])
      expect(payload[:avis][:items].map { it[:title] }).to eq(["Avis demandé à #{expert.email}", "Avis demandé à #{confidential_avis.email_to_display} (confidentiel)"])
      expect(payload[:avis][:items].first).to include(question: '« Que pensez-vous de ce dossier ? »', answer: 'En attente de réponse', binary_question: '« Favorable ? »', binary_answer: 'En attente de réponse')
      expect(payload[:avis][:items].second).to include(answer: 'Réservé', binary_question: nil)
      expect(payload[:messages][:items].map { it[:sender] }).to eq([commentaire.redacted_email, dossier.user_email_for(:display)])
      expect(payload[:messages][:items].first[:body]).to eq("Bonjour,\nmerci & à bientôt")
    end

    it 'hides the annotations and the avis from the usager' do
      payload = payload_for(dossier, dossier.user)

      expect(payload[:annotations]).to be_nil
      expect(payload[:avis]).to be_nil
      expect(payload[:messages][:items].size).to eq(2)
    end

    it 'gives the expert the avis they may see, and the messagerie only when the procedure allows it' do
      payload = payload_for(dossier, expert)

      expect(payload[:annotations]).to be_nil
      expect(payload[:avis][:items].map { it[:title] }).to eq(["Avis demandé à #{expert.email}"])
      expect(payload[:messages]).to be_nil
    end
  end

  describe 'typst document' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) do
      create(:procedure, :published,
        public_type_de_champs: [
          { type: :header_section, libelle: 'Identité', level: 1 },
          { type: :text, libelle: 'Nom' },
          { type: :address, libelle: 'Adresse' },
          { type: :piece_justificative, libelle: 'Justificatif' },
          { type: :repetition, libelle: 'Enfant', children: [{ type: :text, libelle: 'Prénom' }] },
          { type: :carte, libelle: 'Emprise' },
        ],
        private_type_de_champs: [{ type: :text, libelle: 'Statut' }],
        instructeurs: [instructeur])
    end
    let(:dossier) { create(:dossier, :en_instruction, :with_populated_champs, :with_populated_annotations, procedure:) }

    before do
      create(:avis, dossier:, introduction: 'Votre avis ?')
      create(:commentaire, dossier:, body: 'Un message')
      champ = dossier.root_champs_public.find { it.libelle == 'Emprise' }
      champ.update(geo_areas: [build(:geo_area, :selection_utilisateur, :polygon)])
      champ.attach_static_map(Rails.root.join('spec/fixtures/files/image-no-exif.jpg').open, digest: 'abc')
    end

    it 'lays out the sections, the numbered form headings and the map', :external_deps do
      require_tool!('typst')

      TypstService.with_assets do |assets|
        data = described_class.new(dossier, acls: acls_for(dossier, instructeur), assets:).to_h
        document = TypstService.query('dossier', data, '(headings: headings(), tables: tables(), lists: lists(), images: images())', assets:)

        expect(document['headings']).to eq([
          { 'level' => 1, 'text' => "Dossier n° #{dossier.id}" },
          { 'level' => 2, 'text' => 'Dossier' },
          { 'level' => 2, 'text' => 'Identité du demandeur' },
          { 'level' => 2, 'text' => 'Formulaire' },
          { 'level' => 3, 'text' => '1. Identité' },
          { 'level' => 2, 'text' => 'Annotations privées' },
          { 'level' => 2, 'text' => 'Avis' },
          { 'level' => 2, 'text' => 'Messagerie' },
        ])
        expect(document['tables'].first).to include('État', ApplicationController.helpers.dossier_display_state(dossier))
        expect(document['images']).to include('alt' => 'Carte des zones dessinées pour « Emprise »')
        expect(document['lists'].flatten).to include('toto.txt')
      end
    end

    it 'renders a PDF that passes veraPDF PDF/UA-1 validation', :external_deps do
      require_tool!('typst')

      pdf = DossierPdfService.send(:render_typst, dossier, acls: acls_for(dossier, instructeur))

      expect(pdf[0, 5]).to eq('%PDF-')

      require_tool!('verapdf')

      Tempfile.create(['dossier', '.pdf']) do |file|
        file.binmode
        file.write(pdf)
        file.flush

        report, warnings, = Open3.capture3('verapdf', '--format', 'text', '--flavour', 'ua1', file.path)

        expect(report).to start_with('PASS'), -> { "veraPDF PDF/UA-1 validation failed:\n#{report}\n#{warnings}" }
      end
    end
  end
end
