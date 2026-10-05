# frozen_string_literal: true

describe TiptapEditorComponent, type: :component do
  let(:dossier_submitted_message) { build(:dossier_submitted_message) }
  let(:form) do
    ActionView::Helpers::FormBuilder.new(:dossier_submitted_message, dossier_submitted_message, vc_test_controller.view_context, {})
  end

  subject(:rendered) { render_inline(described_class.new(form:, field_name: :tiptap_body, label: "Message personnalisé")) }

  it "renders the formatting toolbar without an underline button" do
    expect(rendered).to have_button("Gras")
    expect(rendered).to have_button("Italique")
    expect(rendered).not_to have_button("Souligné")
    expect(rendered.to_html).not_to include('data-tiptap-action="underline"')
  end

  context "with a custom actions list" do
    subject(:rendered) { render_inline(described_class.new(form:, field_name: :tiptap_body, label: "Message personnalisé", actions: %w[bold heading2])) }

    it "renders only the buttons matching the given actions" do
      expect(rendered).to have_button("Titre")
      expect(rendered).not_to have_button("Liste")
    end

    it "renders a button with its DSFR icon" do
      expect(rendered).to have_css('button.fr-icon-h-1')
    end
  end

  context "with the paragraph action" do
    subject(:rendered) { render_inline(described_class.new(form:, field_name: :tiptap_body, label: "Message personnalisé", actions: %w[hardBreak paragraph])) }

    it "renders the paragraph button with its icon" do
      expect(rendered).to have_button("Paragraphe")
      expect(rendered).to have_css('button.fr-icon-paragraph[data-tiptap-action="paragraph"][title="Paragraphe"]')
    end
  end

  context "with the link action" do
    let(:modal_html) { rendered.to_html }

    it_behaves_like 'a labelled DSFR modal', 'tiptap-link-modal'

    it "keeps the Stimulus target on the dialog" do
      expect(Capybara.string(modal_html)).to have_css('dialog#tiptap-link-modal[data-tiptap-target="linkModal"]', visible: :all)
    end
  end

  it "does not render any tag button when tags: is not given" do
    expect(rendered).not_to have_css('[data-tiptap-target="tag"]')
  end

  it "rend la liste de tags dans le composant quand tags: est fourni" do
    render_inline(described_class.new(
      form: form, field_name: :tiptap_body, label: "Message personnalisé",
      tags: { dossier: [{ id: 'dossier_number', libelle: 'numéro du dossier', description: '' }] }
    ))
    expect(page).to have_button('numéro du dossier')
    expect(page).to have_css('[data-tiptap-target="tag"]')
  end

  context "en mode single_line avec tags repliés" do
    subject(:rendered) do
      render_inline(described_class.new(
        form:, field_name: :tiptap_body, label: "Objet", actions: [], single_line: true, collapsed_tags: true,
        tags: { dossier: [{ id: 'dossier_number', libelle: 'numéro du dossier', description: '' }] }
      ))
    end

    it "ne rend ni toolbar ni modale de lien, et replie les tags derrière un toggle" do
      expect(rendered).not_to have_css('button[data-tiptap-target="button"]')
      expect(rendered).not_to have_css('dialog#tiptap-link-modal')
      expect(rendered.to_html).to include('data-tiptap-single-line-value')
      expect(rendered).to have_button('Balises disponibles')
      expect(rendered).to have_css('.fr-collapse [data-tiptap-target="tag"]')
    end
  end
end
