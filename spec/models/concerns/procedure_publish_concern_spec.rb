# frozen_string_literal: true

describe ProcedurePublishConcern do
  describe "#publish_or_reopen!" do
    let(:canonical_procedure) { procedures.individual }
    let(:administrateur) { canonical_procedure.administrateurs.first }

    let(:procedure) { create(:procedure, administrateurs: [administrateur], zones: [zones.default]) }
    let(:now) { Time.zone.now.beginning_of_minute }

    context 'when the procedure is already published (replayed publish)' do
      let(:procedure) { create(:procedure, :published, administrateurs: [administrateur], zones: [zones.default]) }

      it 'is a no-op instead of failing (RAILS-K6N)' do
        expect { procedure.publish_or_reopen!(administrateur, procedure.path) }.not_to raise_error
        expect(procedure.reload).to be_publiee
      end
    end

    context 'when publishing over a previous canonical procedure' do
      before do
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, canonical_procedure.path)
        end
        procedure.reload
        canonical_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
      end

      it 'unpublishes the canonical procedure' do
        expect(canonical_procedure.unpublished_at).to eq(now)
      end

      it 'creates a new draft revision' do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
        expect(procedure.published_revision.published_at).to eq(now)
      end
    end

    context 'when publishing over a previous procedure with canonical procedure' do
      let(:canonical_path) { 'canonical-path' }
      let(:canonical_procedure) { create(:procedure, :closed, path: canonical_path) }
      let(:parent_procedure) { create(:procedure, :published, administrateurs: [administrateur]) }

      before do
        parent_procedure.update!(canonical_procedure: canonical_procedure)
        parent_procedure.claim_path!(administrateur, canonical_path)
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, canonical_path)
        end
        parent_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).to eq(now)
      end

      it 'unpublishes parent procedure' do
        expect(parent_procedure.unpublished_at).to eq(now)
      end
    end

    context 'when republishing a previously closed procedure' do
      let(:procedure) { procedures.individual }

      before do
        procedure.close!
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, procedure.path)
        end
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).not_to eq(now)
      end

      it "doesn't create a new revision" do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
      end
    end

    context 'when publishing a procedure with the same path as another procedure from another admin' do
      let(:procedure) { create(:procedure, path: 'example-path', administrateurs: [administrateur]) }
      let(:other_procedure) { create(:procedure, path: 'example-path', administrateurs: [create(:administrateur)]) }

      it 'raises an error' do
        expect { procedure.publish_or_reopen!(administrateur, other_procedure.path) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#publish_revision!" do
    let(:administrateur) { create(:administrateur) }
    let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }
    let(:tdc_attributes) { { type_champ: :number, libelle: 'libelle 1' } }
    let(:publication_date) { Time.zone.local(2021, 1, 1, 12, 00, 00) }

    before do
      procedure.draft_revision.add_type_de_champ(tdc_attributes)
    end

    subject do
      travel_to(publication_date) do
        procedure.publish_revision!(administrateur)
      end
    end

    it 'publishes the new revision' do
      subject
      expect(procedure.published_revision).to be_present
      expect(procedure.published_revision.published_at).to eq(publication_date)
      expect(procedure.published_revision.public_root_type_de_champs.first.libelle).to eq('libelle 1')
    end

    it 'creates a new draft revision' do
      expect { subject }.to change(ProcedureRevision, :count).by(1)
      expect(procedure.draft_revision).to be_present
      expect(procedure.draft_revision.public_revision_type_de_champs).to be_present
      expect(procedure.draft_revision.public_root_type_de_champs).to be_present
      expect(procedure.draft_revision.public_root_type_de_champs.first.libelle).to eq('libelle 1')
    end

    it 'records the publishing administrateur' do
      subject

      expect(procedure.published_revision.administrateur).to eq(administrateur)
      expect(procedure.draft_revision.administrateur).to be_nil
    end

    it 'stores the type de champ tree on the published revision only' do
      subject

      published_revision = procedure.published_revision.reload
      type_de_champ = published_revision.public_root_type_de_champs.first
      expect(published_revision.read_attribute(:type_de_champ_tree).public_children)
        .to eq([TypeDeChampNode.new(stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id)])
      expect(procedure.draft_revision.reload.read_attribute(:type_de_champ_tree)).to be_nil
    end

    it 'stores the tree the database holds, whatever the draft loaded before' do
      subject

      stable_id = procedure.draft_revision.revision_type_de_champs.first.stable_id
      edited = Procedure.find(procedure.id).draft_revision.find_and_ensure_exclusive_use(stable_id)
      edited.update!(libelle: 'libelle 1 edited')

      procedure.publish_revision!(administrateur)

      expect(procedure.published_revision.reload.read_attribute(:type_de_champ_tree).public_children.map(&:type_de_champ_id)).to eq([edited.id])
      expect(procedure.draft_revision.reload.revision_type_de_champs.map(&:type_de_champ_id)).to eq([edited.id])
    end

    context 'when the procedure has dossiers' do
      let(:dossier_draft) { create(:dossier, :brouillon, procedure: procedure) }
      let(:dossier_submitted) { create(:dossier, :en_construction, procedure: procedure) }
      let(:dossier_termine) { create(:dossier, :accepte, procedure: procedure) }

      before { [dossier_draft, dossier_submitted, dossier_termine] }

      it 'enqueues rebase jobs for draft dossiers' do
        subject
        expect(DossierRebaseJob).to have_been_enqueued.with(dossier_draft)
        expect(DossierRebaseJob).to have_been_enqueued.with(dossier_submitted)
        expect(DossierRebaseJob).not_to have_been_enqueued.with(dossier_termine)
      end
    end

    context 'when a type de champ is transformed from a drop_down_list with referentiel to a textarea' do
      let(:procedure) { create(:procedure, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :drop_down_list, referentiel:, drop_down_mode: 'advanced' }] }
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:tdc) { procedure.draft_revision.public_root_type_de_champs.last }

      before do
        procedure.draft_revision.public_root_type_de_champs.last.update(type_champ: :textarea, options: { "character_limit" => "" })
      end

      it 'nullifies the referentiel' do
        expect(tdc.referentiel).to be_nil
      end
    end
  end

  describe "#reset_draft_revision!" do
    let(:procedure) { procedures.brouillon }
    let(:tdc_attributes) { { type_champ: :number, libelle: 'libelle 1' } }
    let(:publication_date) { Time.zone.local(2021, 1, 1, 12, 00, 00) }

    context "brouillon procedure" do
      it "should not reset draft revision" do
        procedure.draft_revision.add_type_de_champ(tdc_attributes)
        previous_draft_revision = procedure.draft_revision

        procedure.reset_draft_revision!
        expect(procedure.draft_revision).to eq(previous_draft_revision)
      end
    end

    context "published procedure" do
      let(:procedure) do
        create(
          :procedure,
          :published,
          attestation_acceptation_template: build(:attestation_template),
          dossier_submitted_message: create(:dossier_submitted_message),
          public_type_de_champs: [{ type: :text, libelle: 'published tdc' }]
        )
      end

      it "should reset draft revision" do
        procedure.draft_revision.add_type_de_champ(tdc_attributes)
        previous_draft_revision = procedure.draft_revision
        previous_attestation_template = procedure.attestation_acceptation_template
        previous_dossier_submitted_message = previous_draft_revision.dossier_submitted_message

        expect(procedure.draft_changed?).to be_truthy
        procedure.reset_draft_revision!
        expect(procedure.draft_changed?).to be_falsey
        expect(procedure.draft_revision).not_to eq(previous_draft_revision)
        expect { previous_draft_revision.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(procedure.attestation_acceptation_template).to eq(previous_attestation_template)
        expect(procedure.draft_revision.dossier_submitted_message).to eq(previous_dossier_submitted_message)
      end

      it "does not hand the published type de champ tree over to the new draft" do
        procedure = procedures.individual
        procedure.draft_revision.add_type_de_champ(tdc_attributes)

        procedure.reset_draft_revision!

        expect(procedure.published_revision.read_attribute(:type_de_champ_tree)).to be_present
        expect(procedure.draft_revision.reload.read_attribute(:type_de_champ_tree)).to be_nil
      end

      it "should erase orphan tdc" do
        published_tdc = procedure.published_revision.type_de_champs.first
        draft_tdc = procedure.draft_revision.add_type_de_champ(tdc_attributes)

        procedure.reset_draft_revision!

        expect { published_tdc.reload }.not_to raise_error
        expect { draft_tdc.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
