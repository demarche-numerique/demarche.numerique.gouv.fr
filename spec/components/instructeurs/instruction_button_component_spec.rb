# frozen_string_literal: true

RSpec.describe Instructeurs::InstructionButtonComponent, type: :component do
  include DossierHelper
  include Rails.application.routes.url_helpers

  subject(:rendered) do
    render_inline(described_class.new(dossier:, procedure: dossier.procedure))
  end

  context 'when dossier is en_construction' do
    let(:dossier) { create(:dossier, :en_construction) }

    it 'does not render' do
      expect(rendered.to_s).to be_empty
    end
  end

  context 'when dossier is en_instruction' do
    let(:dossier) { create(:dossier, :en_instruction) }

    it 'renders the instruction button and modal content' do
      expect(rendered).to have_button('Rendre une décision')
      expect(rendered).to have_selector('#modal-instruction-button')
      expect(rendered).to have_selector('#modal-instruction-title', text: "Rendre une décision sur le dossier n° #{dossier.id} - #{dossier.owner_name}")

      expect(rendered).to have_link('Accepter le dossier')
      expect(rendered).to have_link('Refuser le dossier')
      expect(rendered).to have_link('Classer sans suite le dossier')
      expect(rendered).to have_selector('a[data-turbo-method="post"]')
      expect(rendered).not_to have_field('motivation_accept')
      expect(rendered).not_to have_text("L’acceptation du dossier génère automatiquement une attestation à télécharger par l’usager")
    end

    it 'renders the annotation error alert hidden by default when there are no errors' do
      expect(rendered).to have_selector('#alert-error-annotation.hidden .fr-alert--error')
      expect(rendered).to have_selector('#instruction-modal-footer:not(.fr-modal__footer)')
    end
  end

  context 'when dossier is en_instruction with invalid mandatory private annotations' do
    let(:procedure) { create(:procedure, private_type_de_champs:) }
    let(:dossier) { create(:dossier, :en_instruction, procedure:) }
    let(:private_type_de_champs) { [{ type: :text, libelle: 'Appréciation globale', mandatory: true }] }

    subject(:rendered) do
      render_inline(described_class.new(dossier:, procedure:))
    end

    it 'renders the error alert visible, listing the missing annotation' do
      expect(rendered).to have_selector('#alert-error-annotation:not(.hidden) .fr-alert--error')
      expect(rendered).to have_selector('#alert-error-annotation li', text: 'Appréciation globale')
    end

    it 'moves the complete-annotations access to a footer button, not the alert body' do
      expect(rendered).to have_selector('#instruction-modal-footer.fr-modal__footer a.fr-btn', text: 'Compléter les annotations privées')
      expect(rendered).not_to have_selector('#alert-error-annotation a')
    end
  end

  context 'when rendered in batch mode' do
    let(:procedure) { create(:procedure) }

    subject(:rendered) do
      render_inline(described_class.new(batch: true, procedure:))
    end

    it 'renders the batch instruction button' do
      expect(rendered).to have_button('Rendre une décision', disabled: true)
      expect(rendered).to have_selector('button[data-operation="instruction"]')
      expect(rendered).to have_selector('button[data-action="batch-operation#openInstructionModal"]')
    end

    it 'leaves the modal to the batch operation component, outside its form' do
      expect(rendered).not_to have_selector('#modal-instruction-button')
    end

    it 'does not render the annotation warning' do
      expect(rendered).not_to have_selector('#alert-error-annotation')
    end
  end
end
