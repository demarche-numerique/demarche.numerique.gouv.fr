# frozen_string_literal: true

describe EmptyFileValidator do
  def empty_blob(filename: 'empty.pdf')
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(''),
      filename:,
      content_type: 'application/pdf'
    )
  end

  describe "on a has_many_attached association" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.root_champs_public.first }

    it "rejects an empty file" do
      champ.piece_justificative_file = [empty_blob]

      expect(champ.valid?(:champ_value)).to be false
      expect(champ.errors[:piece_justificative_file].join).to include('vide')
    end

    it "rejects an empty file among valid ones" do
      champ.piece_justificative_file = [
        { io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf' },
        empty_blob,
      ]

      expect(champ.valid?(:champ_value)).to be false
    end

    it "accepts a file with content" do
      champ.piece_justificative_file = [
        { io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf' },
      ]

      expect(champ.valid?(:champ_value)).to be true
    end

    it "rejects an empty file even when PJ size validation is disabled" do
      champ.type_de_champ.update(skip_pj_validation: true)
      champ.piece_justificative_file = [empty_blob]

      expect(champ.valid?(:champ_value)).to be false
    end

    it "does not run outside the :champ_value context" do
      champ.piece_justificative_file = [empty_blob]

      expect(champ.valid?).to be true
    end

    it "prevents the attachment from being persisted through the PJ service" do
      champ.piece_justificative_file.purge

      expect(Attachment::PieceJustificativeService.attach_champ_pj(champ, empty_blob.signed_id)).to be false
      expect(champ.reload.piece_justificative_file).not_to be_attached
    end
  end

  # An empty attachment committed before this validation existed must not make
  # its record unsaveable, otherwise the dossier holding it can no longer be
  # submitted. The purge task cleans those up, and is not a deploy prerequisite.
  describe "with an empty attachment already in database" do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.root_champs_public.first }

    before do
      champ.piece_justificative_file = [empty_blob]
      champ.save!(validate: false)
      champ.reload
    end

    it "keeps the record valid without reading its attachments" do
      preloaded_champ = DossierPreloader.load_one(dossier).root_champs_public.first

      expect(count_queries(matching: /active_storage/) { preloaded_champ.validate(:champ_value) }).to eq(0)
      expect(preloaded_champ.errors).to be_empty
    end

    it "still rejects a newly added empty file" do
      champ.piece_justificative_file = champ.piece_justificative_file.blobs + [empty_blob(filename: 'other.pdf')]

      expect(champ.valid?(:champ_value)).to be false
    end

    it "accepts a newly added file with content" do
      champ.piece_justificative_file = champ.piece_justificative_file.blobs + [
        { io: StringIO.new('x'), filename: 'doc.pdf', content_type: 'application/pdf' },
      ]

      expect(champ.valid?(:champ_value)).to be true
    end
  end

  describe "on a signed id held by the record" do
    def batch(justificatif_motivation)
      BatchOperation.new(operation: :accepter, instructeur: instructeurs.default, justificatif_motivation:)
    end

    it "rejects an empty file" do
      record = batch(empty_blob.signed_id)

      expect(record).not_to be_valid
      expect(record.errors[:justificatif_motivation].join).to include('vide')
    end

    it "accepts a file with content" do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('x'), filename: 'motif.pdf', content_type: 'application/pdf')

      expect(batch(blob.signed_id)).to be_valid
    end
  end

  describe "on a has_one_attached association" do
    let(:record) { avis.answered }

    it "rejects an empty file" do
      record.introduction_file = empty_blob

      expect(record).not_to be_valid
      expect(record.errors[:introduction_file].join).to include('vide')
    end

    it "accepts a file with content" do
      record.introduction_file = { io: StringIO.new('x'), filename: 'intro.pdf', content_type: 'application/pdf' }

      expect(record).to be_valid
    end

    it "accepts a record without any attachment" do
      expect(record).to be_valid
    end

    # #attach on a persisted record saves it right away: the validation still
    # runs then, because the attachment is only inserted once it passes.
    it "prevents #attach from replacing a template with an empty file" do
      tdc = create(:type_de_champ_piece_justificative)

      tdc.piece_justificative_template.attach(empty_blob)

      expect(tdc.reload.piece_justificative_template.blob.filename.to_s).to eq('toto.txt')
    end
  end
end
