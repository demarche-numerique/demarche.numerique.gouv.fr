# frozen_string_literal: true

RSpec.describe Instructeurs::ArchiveModalComponent, type: :component do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:dossier) { dossiers.accepte }
  let(:component) { described_class.new(procedure_id: procedure.id, dossier_id: dossier.id) }

  before { allow(component).to receive(:current_instructeur).and_return(instructeur) }

  subject { render_inline(component) }

  context 'for a single dossier' do
    it 'renders a warning modal of its own that archives this dossier' do
      modal_id = "modal-archive-#{dossier.id}"

      expect(subject).to have_selector("dialog##{modal_id}[aria-labelledby='#{modal_id}-title']", visible: :all)
      expect(subject).to have_selector("h2##{modal_id}-title", text: 'Déplacer dans « à archiver »', visible: :all)
      expect(subject).to have_no_selector('h1', visible: :all)
      expect(subject).to have_selector('.fr-notice.fr-notice--info', text: 'Information importante', visible: :all)
      expect(subject).to have_selector("form##{modal_id}-form[action^='/procedures/#{procedure.id}/'][action$='/dossiers/#{dossier.id}/archive'] input[name='_method'][value='patch']", visible: :all)
      expect(subject).to have_selector("input##{modal_id}-dismiss[type='checkbox'][name='dismiss_archive_warning'][value='1']", visible: :all)
      expect(subject).to have_selector("label[for='#{modal_id}-dismiss']", text: 'Ne plus afficher cette information', visible: :all)
      expect(subject).to have_selector("button[type='button'][aria-controls='#{modal_id}']", text: 'Annuler', visible: :all)
      expect(subject).to have_selector("button[type='submit'][form='#{modal_id}-form']", text: 'Confirmer', visible: :all)
      expect(subject).to have_no_selector('form[data-turbo]', visible: :all)
    end
  end

  context 'for a batch' do
    let(:component) { described_class.new(procedure_id: procedure.id) }

    it_behaves_like 'a labelled DSFR modal', 'modal-archive-batch' do
      let(:modal_html) { render_inline(component).to_html }
    end

    it 'posts the archiver operation to the batch endpoint with its own ids' do
      batch_path = Rails.application.routes.url_helpers.instructeur_batch_operations_path(procedure_id: procedure.id)

      expect(subject).to have_selector("dialog#modal-archive-batch form[action='#{batch_path}'][data-turbo='true'][data-batch-operation-target='archiveForm']", visible: :all)
      expect(subject).to have_selector('input[name="batch_operation[operation]"][value="archiver"]', visible: :all)
      expect(subject).to have_selector('button[type="submit"][form="modal-archive-batch-form"]', visible: :all)
      expect(subject).to have_selector('input#modal-archive-batch-dismiss', visible: :all)
    end
  end

  context 'when the instructeur dismissed the warning on this procedure' do
    before { InstructeursProcedure.find_or_initialize_by(instructeur:, procedure:).update!(position: 1, archive_warning_dismissed: true) }

    it { expect(subject.to_html).to be_empty }
  end

  context 'when the instructeur dismissed the warning on another procedure' do
    before { create(:instructeurs_procedure, instructeur:, archive_warning_dismissed: true) }

    it { expect(subject).to have_selector("dialog#modal-archive-#{dossier.id}", visible: :all) }
  end

  context 'without instructeur' do
    let(:instructeur) { nil }

    it { expect(subject.to_html).to be_empty }
  end
end
