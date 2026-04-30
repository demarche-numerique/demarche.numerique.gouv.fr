# frozen_string_literal: true

describe "ActiveStorage configuration" do
  describe "blob analysis" do
    let(:blob) do
      image_path = Rails.root.join("spec/fixtures/files/logo_test_procedure.png")
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(image_path),
        filename: "test.png",
        content_type: "image/png"
      )
    end

    it "does not enqueue AnalyzeJob when an image blob is created" do
      expect {
        ActiveStorage::Attachment.create!(
          name: "test",
          record: create(:dossier),
          blob: blob
        )
      }.not_to have_enqueued_job(ActiveStorage::AnalyzeJob)
    end

    it "pre-marks blobs as analyzed and does not UPDATE active_storage_blobs when an attachment is created" do
      # The blob must be pre-marked as analyzed at INSERT time so that
      # `Attachment#analyze_blob_later` (after_create_commit) short-circuits
      # via its `unless blob.analyzed?` guard. Otherwise, with `analyzers = []`,
      # ActiveStorage falls back to NullAnalyzer whose `analyze_later? == false`,
      # and `analyze` runs inline, issuing an unnecessary UPDATE on
      # `active_storage_blobs`. Under contention (e.g., a batch op with N
      # workers attaching the same blob), this UPDATE serializes on the same
      # row and hits PG statement_timeout in production.
      blob_updates = []
      callback = -> (_, _, _, _, payload) {
        sql = payload[:sql]
        blob_updates << sql if sql.match?(/UPDATE\s+"active_storage_blobs"/i)
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        ActiveStorage::Attachment.create!(
          name: "test",
          record: create(:dossier),
          blob: blob
        )
      end

      expect(blob.analyzed?).to be(true)
      expect(blob_updates).to be_empty
    end
  end
end
