# frozen_string_literal: true

describe Procedure::ErrorsSummary, type: :component do
  subject { render_inline(described_class.new(procedure:, validation_context:)) }

  describe 'validations context' do
    let(:procedure) { create(:procedure, private_type_de_champs:, public_type_de_champs:) }
    let(:private_type_de_champs) { [{ type: :repetition, children: [], libelle: 'private' }] }
    let(:public_type_de_champs) { [{ type: :repetition, children: [], libelle: 'public' }] }

    before { subject }

    context 'when :publication' do
      let(:validation_context) { :publication }

      it 'shows errors and links for public and private tdc' do
        expect(page).to have_content("Erreur : Des problèmes empêchent la publication de la démarche")
        expect(page).to have_selector("a", text: "public")
        expect(page).to have_selector("a", text: "private")
        expect(page).to have_text("doit comporter au moins un champ répétable", count: 2)
      end
    end

    context 'when :public_type_de_champs_editor' do
      let(:validation_context) { :public_type_de_champs_editor }

      it 'shows errors and links for public only tdc' do
        expect(page).to have_text("Erreur : Les champs du formulaire contiennent des erreurs")
        expect(page).to have_selector("a", text: "public")
        expect(page).to have_text("doit comporter au moins un champ répétable", count: 1)
        expect(page).not_to have_selector("a", text: "private")
      end
    end

    context 'when :private_type_de_champs_editor' do
      let(:validation_context) { :private_type_de_champs_editor }

      it 'shows errors and links for private only tdc' do
        expect(page).to have_text("Erreur : Les annotations privées contiennent des erreurs")
        expect(page).to have_selector("a", text: "private")
        expect(page).to have_text("doit comporter au moins un champ répétable")
        expect(page).not_to have_selector("a", text: "public")
      end
    end
  end

  describe 'render all kind of champs errors' do
    include Logic

    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { libelle: 'repetition requires children', type: :repetition, children: [] },
        { libelle: 'drop down list requires options', type: :drop_down_list, options: [] },
        { libelle: 'invalid condition', type: :text, condition: ds_eq(constant(true), constant(1)) },
        { libelle: 'regexp invalid', type: :formatted, formatted_mode: 'advanced', expression_reguliere_exemple_text: 'kthxbye', expression_reguliere: /{/ },
      ])
    end

    let(:validation_context) { :public_type_de_champs_editor }

    before do
      drop_down_public = procedure.draft_revision.public_root_type_de_champs.find(&:any_drop_down_list?)
      drop_down_public.update!(drop_down_options: [])
      subject
    end

    it 'renders all errors  and links on champ' do
      expect(page).to have_selector("a", text: "drop down list requires options")
      expect(page).to have_content("doit comporter au moins un choix sélectionnable")

      expect(page).to have_selector("a", text: "repetition requires children")
      expect(page).to have_content("doit comporter au moins un champ répétable")

      expect(page).to have_selector("a", text: "invalid condition")
      expect(page).to have_content("a une logique conditionnelle invalide")

      expect(page).to have_selector("a", text: "regexp invalid")
      expect(page).to have_content("est invalide, veuillez la corriger")
    end
  end

  describe 'render error for other kind of associated objects' do
    include Logic

    let(:validation_context) { :publication }
    let(:procedure) { create(:procedure, attestation_acceptation_template:, email_depose:) }
    let(:attestation_acceptation_template) { build(:attestation_template, :v2) }
    let(:email_depose) { build(:email_depose) }

    before do
      procedure.email_depose.update_column(:body, '--invalidtag--')
      procedure.draft_revision.update(ineligibilite_enabled: true, ineligibilite_rules: ds_eq(constant(true), constant(1)), ineligibilite_message: 'ko')

      procedure.attestation_acceptation_template.update_column(:json_body, { type: :doc, content: [{ type: :mention, attrs: { id: "tdc123", label: "oops" } }] })
      subject
    end

    it 'render error nicely' do
      expect(page).to have_selector("a", text: "Les règles d’inéligibilité")
      expect(page).to have_selector("a[href*='v2']", text: "Le modèle d’attestation")
      expect(page).to have_selector("a[href*='email_templates']", text: "Le modèle d’email « Accusé de réception »")
      expect(page).to have_text('contient la balise « invalidtag » qui n’existe pas')
      expect(page).to have_text("n’est pas valide", count: 1)
    end
  end

  describe 'render detailed error for mail template with tiptap body' do
    let(:validation_context) { :publication }
    let(:procedure) { create(:procedure, email_depose: build(:email_depose)) }

    before do
      procedure.email_depose.update_column(:json_body, { type: :doc, content: [{ type: :paragraph, content: [{ type: :mention, attrs: { id: "tdc999999", label: "Nom du projet" } }] }] })
      subject
    end

    it 'renders the underlying tag error with a link to the template editor' do
      expect(page).to have_selector("a[href*='email_templates/depose']", text: "Le modèle d’email « Accusé de réception »")
      expect(page).to have_text('contient la balise « Nom du projet » qui a été supprimée dans les modifications en cours du formulaire')
      expect(page).to have_no_text(/translation missing/i)
      expect(page).to have_no_text("n’est pas valide")
    end
  end

  describe 'render error for attestation v1' do
    let(:validation_context) { :publication }
    let(:procedure) { create(:procedure, attestation_acceptation_template:) }
    let(:attestation_acceptation_template) { build(:attestation_template) }

    before do
      procedure.attestation_acceptation_template.update_column(:body, '--invalidtag--')
      subject
    end

    it 'render error nicely' do
      expect(page).to have_selector("a:not([href*='v2'])", text: "Le modèle d’attestation")
      expect(page).to have_text("n’est pas valide", count: 1)
    end
  end
end
