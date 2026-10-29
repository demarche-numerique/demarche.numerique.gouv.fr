# frozen_string_literal: true

module Maintenance
  RSpec.describe T20261015destroyOrphanDraftRevisionsTask do
    let(:procedure) { procedures.individual }
    let(:published_revision) { procedure.published_revision }
    # a draft a double publication left behind, never published
    let(:orphan_draft) { procedure.create_new_revision(published_revision) }

    before { published_revision.create_dossier_submitted_message!(message_on_submit_by_usager: 'Merci') }

    describe "#collection" do
      subject(:collection) { described_class.collection.where(procedure:) }

      it "holds the drafts never published, which the procedure no longer points to" do
        expect(collection).to eq([orphan_draft])
      end
    end

    describe "#process" do
      it "destroys the draft and keeps the dossier submitted message it shares" do
        message = published_revision.dossier_submitted_message
        expect(orphan_draft.dossier_submitted_message).to eq(message)

        described_class.process(orphan_draft)

        expect(ProcedureRevision.exists?(orphan_draft.id)).to be(false)
        expect(published_revision.reload.dossier_submitted_message).to eq(message)
      end

      it "destroys the dossier submitted message only the draft holds" do
        orphan_draft.update!(dossier_submitted_message: DossierSubmittedMessage.create!(message_on_submit_by_usager: 'Brouillon'))
        message = orphan_draft.dossier_submitted_message

        described_class.process(orphan_draft)

        expect(DossierSubmittedMessage.exists?(message.id)).to be(false)
      end
    end
  end
end
