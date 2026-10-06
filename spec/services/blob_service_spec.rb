# frozen_string_literal: true

RSpec.describe BlobService do
  describe '.purge_blobs_with_variants' do
    # Blobs are created against the real (disk) service, then flipped to openstack
    # and purged against a mocked openstack service — installed here, once every
    # blob exists.
    def purge_blobs_with_variants(&block)
      service = double('openstack service', container: 'bucket', name: :openstack)
      allow(service).to receive(:client).and_return(client) # reached via service.send(:client)
      allow(ActiveStorage::Blob).to receive(:service).and_return(service)
      BlobService.purge_blobs_with_variants([blob.id], &block)
    end

    let(:client) { double('openstack client') }

    let!(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("old"), filename: "old.txt", content_type: "text/plain")
        .tap { it.update_column(:service_name, 'openstack') }
    end

    before do
      allow(client).to receive(:delete_multiple_objects).and_return(double(body: { 'Errors' => [] }))
    end

    it 'drops the blob row' do
      expect { purge_blobs_with_variants }.to change { ActiveStorage::Blob.exists?(id: blob.id) }.from(true).to(false)
    end

    it 'bulk-deletes the parent file (safety net against a missed X-Delete-At)' do
      expect(client).to receive(:delete_multiple_objects)
        .with('bucket', [blob.key])
        .and_return(double(body: { 'Errors' => [] }))

      purge_blobs_with_variants
    end

    context 'when the blob is an image with variants' do
      let!(:variant_blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("variant"), filename: "v.png", content_type: "image/png")
          .tap { it.update_column(:service_name, 'openstack') }
      end
      let!(:variant_record) { ActiveStorage::VariantRecord.create!(blob:, variation_digest: "digest") }
      let!(:image_attachment) { ActiveStorage::Attachment.create!(name: "image", record: variant_record, blob: variant_blob) }

      it 'bulk-deletes both variant and parent files, then drops every row' do
        expect(client).to receive(:delete_multiple_objects)
          .with('bucket', match_array([variant_blob.key, blob.key]))
          .and_return(double(body: { 'Errors' => [] }))

        purge_blobs_with_variants

        expect(ActiveStorage::Blob.where(id: [blob.id, variant_blob.id])).not_to exist
        expect(ActiveStorage::VariantRecord.where(id: variant_record.id)).not_to exist
        expect(ActiveStorage::Attachment.where(id: image_attachment.id)).not_to exist
      end

      it 'splits the files over several bulk deletes past BULK_DELETE_LIMIT' do
        stub_const('BlobService::BULK_DELETE_LIMIT', 1)

        purge_blobs_with_variants

        expect(client).to have_received(:delete_multiple_objects).with('bucket', [blob.key]).ordered
        expect(client).to have_received(:delete_multiple_objects).with('bucket', [variant_blob.key]).ordered
      end

      it 'drops a variant record left without attachment (it would block the parent blob delete)' do
        orphan_variant_record = ActiveStorage::VariantRecord.create!(blob:, variation_digest: "orphan-digest")

        purge_blobs_with_variants

        expect(ActiveStorage::VariantRecord.where(id: orphan_variant_record.id)).not_to exist
      end

      it 'purges both attachments when two variant records share the same variant blob' do
        second_variant_record = ActiveStorage::VariantRecord.create!(blob:, variation_digest: "digest-2")
        second_attachment = ActiveStorage::Attachment.create!(name: "image", record: second_variant_record, blob: variant_blob)

        purge_blobs_with_variants

        expect(ActiveStorage::Attachment.where(id: [image_attachment.id, second_attachment.id])).not_to exist
        expect(ActiveStorage::Blob.where(id: variant_blob.id)).not_to exist
      end

      it 'returns an audit of the parent and its variant blob' do
        expect(purge_blobs_with_variants).to match_array([
          { id: blob.id, key: blob.key, file_deleted: true, variant: false, parent_id: nil },
          { id: variant_blob.id, key: variant_blob.key, file_deleted: true, variant: true, parent_id: blob.id },
        ])
      end

      it 'yields the audit entries even when dropping the rows fails' do
        allow(ActiveStorage::Blob).to receive(:transaction).and_raise(ActiveRecord::Deadlocked)

        yielded = []
        expect { purge_blobs_with_variants { yielded << it } }.to raise_error(ActiveRecord::Deadlocked)

        expect(yielded.map { it[:id] }).to match_array([blob.id, variant_blob.id])
      end

      it 'reports per-object bulk delete errors to Sentry and marks the file as not deleted' do
        errors = [["bucket/#{variant_blob.key}", "409 Conflict"]]
        allow(client).to receive(:delete_multiple_objects).and_return(double(body: { 'Errors' => errors }))

        expect(Sentry).to receive(:capture_message).with("Bulk delete errors", extra: { errors: })

        audit = purge_blobs_with_variants
        expect(audit.find { it[:id] == variant_blob.id }).to include(file_deleted: false)
        expect(audit.find { it[:id] == blob.id }).to include(file_deleted: true)
      end
    end

    context 'when the blob is stored on another service' do
      let!(:blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("other"), filename: "other.txt", content_type: "text/plain")
      end

      it 'leaves its file and row untouched' do
        expect(client).not_to receive(:delete_multiple_objects)

        expect { purge_blobs_with_variants }.not_to change { ActiveStorage::Blob.exists?(id: blob.id) }
      end
    end
  end
end
