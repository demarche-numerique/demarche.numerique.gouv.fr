# frozen_string_literal: true

RSpec.describe Instructeurs::ArchiveModalComponent, type: :component do
  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:component) { described_class.new }

  before { allow(component).to receive(:current_instructeur).and_return(instructeur) }

  subject { render_inline(component) }

  context 'for a single dossier' do
    it 'renders the warning modal with a PATCH form waiting for its action' do
      expect(subject).to have_selector('dialog#modal-archive[aria-labelledby="modal-archive-title"][data-controller="modal-escape"]', visible: :all)
      expect(subject).to have_selector('h1#modal-archive-title', text: 'Déplacer dans “à archiver”', visible: :all)
      expect(subject).to have_selector('.fr-notice.fr-notice--info', text: 'Information importante', visible: :all)
      expect(subject).to have_selector('form[action=""] input[name="_method"][value="patch"]', visible: :all)
      expect(subject).to have_selector('input#modal-archive-dismiss[type="checkbox"][name="dismiss_archive_warning"][value="1"][data-action="keydown.esc->modal-escape#close"]', visible: :all)
      expect(subject).to have_selector('label[for="modal-archive-dismiss"]', text: 'Ne plus afficher cette information', visible: :all)
      expect(subject).to have_selector('button[type="button"][aria-controls="modal-archive"]', text: 'Annuler', visible: :all)
      expect(subject).to have_selector('button[type="submit"]', text: 'Confirmer', visible: :all)
      expect(subject).to have_no_selector('form[data-turbo]', visible: :all)
    end
  end

  context 'for a batch' do
    let(:component) { described_class.new(procedure:) }

    it 'posts the archiver operation to the batch endpoint with its own ids' do
      batch_path = Rails.application.routes.url_helpers.instructeur_batch_operations_path(procedure_id: procedure.id)

      expect(subject).to have_selector("dialog#modal-archive-batch form[action='#{batch_path}'][data-turbo='true'][data-batch-operation-target='archiveForm']", visible: :all)
      expect(subject).to have_selector('input[name="batch_operation[operation]"][value="archiver"]', visible: :all)
      expect(subject).to have_selector('h1#modal-archive-batch-title', visible: :all)
      expect(subject).to have_selector('input#modal-archive-batch-dismiss', visible: :all)
    end
  end

  context 'when the instructeur dismissed the warning' do
    before { instructeur.update!(archive_warning_dismissed: true) }

    it { expect(subject.to_html).to be_empty }
  end

  context 'without instructeur' do
    let(:instructeur) { nil }

    it { expect(subject.to_html).to be_empty }
  end
end
