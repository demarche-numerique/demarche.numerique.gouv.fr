# frozen_string_literal: true

describe Procedure::ErrorsSummary, type: :component do
  subject { render_inline(described_class.new(procedure:, validation_context:)) }

  describe 'validations context' do
    let(:procedure) { create(:procedure, types_de_champ_private:, types_de_champ_public:) }
    let(:types_de_champ_private) { [{ type: :repetition, children: [], libelle: 'private' }] }
    let(:types_de_champ_public) { [{ type: :repetition, children: [], libelle: 'public' }] }

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

    context 'when :types_de_champ_public_editor' do
      let(:validation_context) { :types_de_champ_public_editor }

      it 'shows errors and links for public only tdc' do
        expect(page).to have_text("Erreur : Les champs du formulaire contiennent des erreurs")
        expect(page).to have_selector("a", text: "public")
        expect(page).to have_text("doit comporter au moins un champ répétable", count: 1)
        expect(page).not_to have_selector("a", text: "private")
      end
    end

    context 'when :types_de_champ_private_editor' do
      let(:validation_context) { :types_de_champ_private_editor }

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
      create(:procedure, id: 1, types_de_champ_public: [
        { libelle: 'repetition requires children', type: :repetition, children: [] },
        { libelle: 'drop down list requires options', type: :drop_down_list, options: [] },
        { libelle: 'invalid condition', type: :text, condition: ds_eq(constant(true), constant(1)) },
        { libelle: 'header sections must have consistent order', type: :header_section, level: 2 },
        { libelle: 'regexp invalid', type: :formatted, formatted_mode: 'advanced', expression_reguliere_exemple_text: 'kthxbye', expression_reguliere: /{/ },
      ])
    end

    let(:validation_context) { :types_de_champ_public_editor }

    before do
      drop_down_public = procedure.draft_revision.types_de_champ_public.find(&:any_drop_down_list?)
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

      expect(page).to have_selector("a", text: "header sections must have consistent order")
      expect(page).to have_content("devrait être précédé d’un titre de niveau 1")

      expect(page).to have_selector("a", text: "regexp invalid")
      expect(page).to have_content("est invalide, veuillez la corriger")
    end
  end

  describe 'render error for other kind of associated objects' do
    include Logic

    let(:validation_context) { :publication }
    let(:procedure) { create(:procedure, attestation_acceptation_template:, initiated_mail:) }
    let(:attestation_acceptation_template) { build(:attestation_template, :v2) }
    let(:initiated_mail) { build(:initiated_mail) }

    before do
      procedure.initiated_mail.update_column(:body, '--invalidtag--')
      procedure.draft_revision.update(ineligibilite_enabled: true, ineligibilite_rules: ds_eq(constant(true), constant(1)), ineligibilite_message: 'ko')

      procedure.attestation_acceptation_template.update_column(:json_body, { type: :doc, content: [{ type: :mention, attrs: { id: "tdc123", label: "oops" } }] })
      subject
    end

    it 'render error nicely' do
      expect(page).to have_selector("a", text: "Les règles d’inéligibilité")
      expect(page).to have_selector("a[href*='v2']", text: "Le modèle d’attestation")
      expect(page).to have_selector("a", text: "L’adresse électronique de notification de passage de dossier en instruction")
      expect(page).to have_text("n’est pas valide", count: 2)
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
