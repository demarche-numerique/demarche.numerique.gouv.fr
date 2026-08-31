# frozen_string_literal: true

describe Emails::Depose, type: :model do
  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'nom' }]) }
  let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }
  let(:mail) { described_class.default_for_procedure(procedure) }

  let(:email_subject) { '' }
  let(:email_body) { '' }

  subject do
    mail.subject = email_subject
    mail.body = email_body
    mail.validate
    mail
  end

  describe 'body' do
    context 'empty template' do
      it { expect(subject.errors).to be_empty }
    end

    context 'template with valid tag' do
      let(:email_body) { 'foo --numéro du dossier-- bar' }

      it { expect(subject.errors).to be_empty }
    end

    context 'template with new valid tag' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors).to be_empty }
    end

    context 'template with invalid tag' do
      let(:email_body) { 'foo --numéro du -- bar' }

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"numéro du\" qui n’existe pas. Supprimer la balise"]) }
    end

    context 'template with unpublished tag' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"age\" qui n’est pas encore publiée. Publier la nouvelle version de la démarche et recommencer"]) }
    end

    context 'template with removed but unpublished tag' do
      let(:email_body) { 'foo --nom-- bar' }

      before do
        procedure.draft_revision.remove_type_de_champ(type_de_champ.stable_id)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"nom\" qui a été supprimée dans les modifications en cours du formulaire. Supprimer cette balise ou réinitialiser les modifications du formulaire puis recommencer"]) }
    end

    context 'template with removed tag' do
      let(:email_body) { 'foo --nom-- bar' }

      before do
        procedure.draft_revision.remove_type_de_champ(type_de_champ.stable_id)
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"nom\" qui a été supprimée. Supprimer la balise"]) }
    end

    context 'template with new tag and old dossier' do
      let(:email_body) { 'foo --age-- bar' }

      before do
        create(:dossier, :en_construction, procedure: procedure)
        procedure.draft_revision.add_type_de_champ(type_champ: :integer_number, libelle: 'age')
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect(subject.errors.full_messages).to eq(["Le champ « Corps de l’email » contient la balise \"age\" qui n’existe pas sur un des dossiers en cours de traitement. Supprimer la balise"]) }
    end
  end
end

describe EmailTemplate do
  let(:procedure) { procedures.individual }
  let(:mail) { Emails::PasseEnInstruction.default_for_procedure(procedure) }
  let(:dossier) { create(:dossier, procedure: procedure) }
  let(:dossier2) { create(:dossier, procedure: procedure) }
  let(:email_depose) { create(:email_depose, procedure: procedure) }
  let(:justificatif) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

  shared_examples "can replace tokens in template" do
    describe 'with no token to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] rien à remplacer' }
      it do
        is_expected.to eq("[demarche.numerique.gouv.fr] rien à remplacer")
      end
    end

    describe 'with one token to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] Dossier : --numéro du dossier--' }
      it do
        is_expected.to eq("[demarche.numerique.gouv.fr] Dossier : #{dossier.id}")
      end
    end

    describe 'with multiples tokens to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] --numéro du dossier-- --libellé démarche-- --lien dossier--' }
      it do
        expected =
          "[demarche.numerique.gouv.fr] #{dossier.id} #{dossier.procedure.libelle} " +
          "<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}\">http://test.host/dossiers/#{dossier.id}</a>"

        is_expected.to eq(expected)
      end
    end
  end

  describe '#subject_for_dossier' do
    before { email_depose.subject = template }
    subject { email_depose.subject_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe '#body_for_dossier' do
    before { email_depose.body = template }
    subject { email_depose.body_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe 'tags' do
    describe 'in initiated mail' do
      it "does not treat date de passage en instruction as a tag" do
        expect(email_depose.tags).not_to include(include({ libelle: 'date de passage en instruction' }))
      end
    end

    describe 'in received mail' do
      let(:email_passe_en_instruction) { create(:email_passe_en_instruction, procedure: procedure) }

      it "treats date de passage en instruction as a tag" do
        expect(email_passe_en_instruction.tags).to include(include({ libelle: 'date de passage en instruction' }))
      end
    end

    describe '--lien attestation--' do
      let(:attestation_template) { build(:attestation_template, activated: true) }
      let(:procedure) { create(:procedure, attestation_acceptation_template: attestation_template) }

      subject { mail.body_for_dossier(dossier) }

      context 'acceptation' do
        let(:kind) { AttestationTemplate.kinds.fetch(:acceptation) }

        before do
          dossier.accepte!
          AttestationPdfGenerationJob.perform_now(dossier)
          dossier.reload
          mail.body = "--lien attestation--"
        end

        describe "in closed mail without justificatif" do
          let(:mail) { create(:email_accepte, procedure: procedure) }
          it do
            is_expected.to eq("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>")
            is_expected.to_not include("Télécharger le justificatif")
          end
        end

        describe "in closed mail with justificatif" do
          before do
            dossier.justificatif_motivation.attach(justificatif)
          end
          let(:mail) { create(:email_accepte, procedure: procedure) }

          it do
            expect(dossier.justificatif_motivation).to be_attached
            is_expected.to include("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>")
            is_expected.to_not include("Télécharger le justificatif")
          end
        end

        describe "in refuse mail" do
          let(:mail) { create(:email_refuse, procedure: procedure) }

          it { is_expected.to include("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>") }
        end

        describe "in without continuation mail" do
          let(:mail) { create(:email_classe_sans_suite, procedure: procedure) }

          it { is_expected.to eq("--lien attestation--") }
        end
      end
    end

    shared_examples 'inserting the --lien document justificatif-- tag' do
      let(:procedure) { create(:procedure) }

      subject { mail.body_for_dossier(dossier) }

      before do
        mail.body = "--lien document justificatif--"
      end

      describe 'without justificatif' do
        it { is_expected.to include("[l’instructeur n’a pas joint de document supplémentaire]") }
      end

      describe 'with justificatif' do
        before do
          dossier.justificatif_motivation.attach(justificatif)
        end
        it do
          expect(dossier.justificatif_motivation).to be_attached
          is_expected.to include("Télécharger le document justificatif")
        end
      end
    end

    context 'in closed mail' do
      let(:mail) { create(:email_accepte, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'in refused mail' do
      let(:mail) { create(:email_refuse, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'in without continuation mail' do
      let(:mail) { create(:email_classe_sans_suite, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'sva/svr' do
      let(:procedure) { create(:procedure, :sva) }
      let(:email_passe_en_instruction) { create(:email_passe_en_instruction, procedure:) }
      it "treats date de passage en instruction as a tag" do
        expect(email_passe_en_instruction.tags).to include(include({ libelle: 'date prévisionnelle SVA/SVR' }))
      end
    end
  end

  describe '#replace_tags' do
    before { email_depose.body = "n --numéro du dossier--" }
    it "avoids side effects" do
      expect(email_depose.body_for_dossier(dossier)).to eq("n #{dossier.id}")
      expect(email_depose.body_for_dossier(dossier2)).to eq("n #{dossier2.id}")
    end
  end

  describe '#tiptap_inline_nodes_for' do
    it 'résout --numéro du dossier-- en mention' do
      nodes = mail.tiptap_inline_nodes_for('Dossier --numéro du dossier--')
      expect(nodes).to eq([
        { "type" => "text", "text" => "Dossier " },
        { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
      ])
    end

    it 'garde un libellé inconnu en texte littéral' do
      nodes = mail.tiptap_inline_nodes_for('Bonjour --libellé inexistant--')
      expect(nodes).to eq([
        { "type" => "text", "text" => "Bonjour " },
        { "type" => "text", "text" => "--libellé inexistant--" },
      ])
    end

    it 'retourne [] pour une chaîne vide' do
      expect(mail.tiptap_inline_nodes_for('')).to eq([])
    end

    it 'préserve un texte composé uniquement d’espaces' do
      expect(mail.tiptap_inline_nodes_for(' ')).to eq([{ "type" => "text", "text" => " " }])
    end
  end

  describe 'accesseurs tiptap' do
    it 'tiptap_body= parse le JSON dans json_body' do
      mail.tiptap_body = '{"type":"doc","content":[]}'
      expect(mail.json_body).to eq({ "type" => "doc", "content" => [] })
    end

    it 'tiptap_body_or_default renvoie json_body si présent' do
      mail.json_body = { "type" => "doc", "content" => [{ "type" => "paragraph" }] }
      expect(JSON.parse(mail.tiptap_body_or_default)).to eq(mail.json_body)
    end

    it 'tiptap_body_or_default convertit le body legacy sinon' do
      mail.json_body = nil
      mail.body = '<div>Bonjour <strong>usager</strong></div>'
      doc = JSON.parse(mail.tiptap_body_or_default)
      expect(doc["content"].first["type"]).to eq("paragraph")
      expect(doc["content"].first["content"]).to include({ "type" => "text", "text" => "usager", "marks" => [{ "type" => "bold" }] })
    end

    it 'tiptap_subject_or_default convertit le subject legacy en doc mono-ligne' do
      mail.json_subject = nil
      mail.subject = 'Dossier --numéro du dossier--'
      doc = JSON.parse(mail.tiptap_subject_or_default)
      expect(doc["type"]).to eq("doc")
      expect(doc["content"].first["type"]).to eq("paragraph")
      expect(doc["content"].first["content"]).to include({ "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } })
    end
  end

  describe 'rendu dual' do
    let(:dossier) { create(:dossier, :en_instruction, procedure:) }

    it 'body_for_dossier utilise json_body si présent (rend le HTML via TiptapService)' do
      mail.json_body = {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => "Dossier nº " },
              { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
            ],
          },
        ],
      }
      html = mail.body_for_dossier(dossier)
      expect(html).to include("Dossier nº #{dossier.id}")
    end

    it 'body_for_dossier retombe sur le legacy si json_body absent' do
      mail.json_body = nil
      mail.body = 'Bonjour --numéro du dossier--'
      expect(mail.body_for_dossier(dossier)).to include(dossier.id.to_s)
    end

    it 'rend un hardBreak en simple <br> (comme le saut de ligne legacy)' do
      mail.json_body = {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => "Cordialement," },
              { "type" => "hardBreak" },
              { "type" => "text", "text" => "Service" },
            ],
          },
        ],
      }
      html = mail.body_for_dossier(dossier)
      expect(html).to include("Cordialement,<br>Service")
      expect(html).not_to include("<br><br>")
    end

    it 'subject_for_dossier utilise json_subject si présent' do
      mail.json_subject = {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "text", "text" => "Dossier " },
              { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
            ],
          },
        ],
      }
      expect(mail.subject_for_dossier(dossier)).to eq("Dossier #{dossier.id}")
    end
  end

  describe 'validation des tags JSON' do
    it 'invalide un tag de champ inexistant dans json_body' do
      mail.json_body = {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "mention", "attrs" => { "id" => "tdc999999", "label" => "champ fantôme" } },
            ],
          },
        ],
      }
      expect(mail).not_to be_valid
      expect(mail.errors[:json_body]).to be_present
      expect(mail.errors.full_messages_for(:json_body).first).to include("Le champ « Corps de l’email »")
      expect(mail.errors.full_messages_for(:json_body).first).not_to match(/translation missing/i)
    end

    [Emails::Depose, Emails::DeposeEtPasseEnInstruction, Emails::DeposeEtAccepte, Emails::PasseEnInstruction, Emails::Accepte, Emails::Refuse, Emails::ClasseSansSuite, Emails::RepasseEnInstruction].each do |klass|
      it "produit des messages d’erreur traduits pour #{klass.name}" do
        template = klass.default_for_procedure(procedure)
        template.json_subject = { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "mention", "attrs" => { "id" => "tdc999999", "label" => "champ fantôme" } }] }] }
        template.json_body = template.json_subject
        expect(template).not_to be_valid
        expect(template.errors.full_messages).to be_present
        template.errors.full_messages.each do |message|
          expect(message).not_to match(/translation missing/i)
        end
      end
    end

    it 'json_body vide reste valide' do
      mail.json_body = nil
      expect(mail).to be_valid
    end

    it 'reste valide si json_body est valide même si le body legacy contient un tag invalide' do
      mail.json_body = { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "OK" }] }] }
      mail.body = 'Bonjour --libellé totalement inexistant--'
      expect(mail).to be_valid
    end

    it 'invalide via :json_body (et pas :body) quand json_body est présent et invalide' do
      mail.json_body = { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "mention", "attrs" => { "id" => "tdc999999", "label" => "x" } }] }] }
      mail.body = 'Bonjour'
      expect(mail).not_to be_valid
      expect(mail.errors[:json_body]).to be_present
      expect(mail.errors[:body]).to be_empty
    end

    it 'valide le body legacy quand json_body est absent' do
      mail.json_body = nil
      mail.body = 'Bonjour --libellé totalement inexistant--'
      expect(mail).not_to be_valid
      expect(mail.errors[:body]).to be_present
    end

    it 'invalide une mention d’une balise indisponible pour l’état du template (parité legacy)' do
      decision_mention = {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph", "content" => [
              { "type" => "mention", "attrs" => { "id" => "dossier_processed_at", "label" => "date de décision" } },
            ],
          },
        ],
      }

      mail.json_body = decision_mention
      expect(mail).not_to be_valid
      expect(mail.errors[:json_body]).to be_present

      email_accepte = Emails::Accepte.default_for_procedure(procedure)
      email_accepte.json_body = decision_mention
      expect(email_accepte).to be_valid
    end
  end

  describe 'declarative variants' do
    # La constante est la seule source de l’association : une variante ajoutée à
    # la hiérarchie sans y être listée aurait des lignes invisibles.
    it 'lists every depose type' do
      Rails.application.eager_load!

      expect(Emails::DEPOSE_TYPES).to match_array([Emails::Depose, *Emails::Depose.descendants].map(&:name))
    end

    it 'renders the combined en_instruction default' do
      procedure = build(:procedure, declarative_with_state: :en_instruction)
      template = Emails::DeposeEtPasseEnInstruction.default_for_procedure(procedure)
      expect(template.subject).to include('a bien été déposé et va être examiné')
      expect(template.body).to include('pris en charge')
    end

    it 'renders the acceptance attestation variant when the attestation is activated' do
      procedure = build(:procedure, declarative_with_state: :accepte, attestation_acceptation_template: build(:attestation_template, activated: true))
      template = Emails::DeposeEtAccepte.default_for_procedure(procedure)
      expect(template.body).to include('--lien attestation--')
    end

    it 'renders the plain acceptance variant otherwise' do
      procedure = build(:procedure, declarative_with_state: :accepte)
      template = Emails::DeposeEtAccepte.default_for_procedure(procedure)
      expect(template.body).to include('--date de décision--')
      expect(template.body).not_to include('--lien attestation--')
    end
  end
end
