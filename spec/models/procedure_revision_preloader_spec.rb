# frozen_string_literal: true

describe ProcedureRevisionPreloader do
  let(:procedure) do
    create(:procedure, :published,
           types_de_champ_public: [
             { type: :piece_justificative },
             { type: :integer_number },
             { type: :decimal_number },
           ],
           types_de_champ_private: [
             { type: :text },
             { type: :textarea },
           ])
  end

  describe '.load_one' do
    let(:revision) { procedure.draft_revision }
    subject { ProcedureRevisionPreloader.load_one(revision) }

    it 'assigns stuffs correctly' do
      # check it changes loaded from false to true
      expect { subject }.to change { procedure.draft_revision.association(:revision_types_de_champ).loaded? }.from(false).to(true)

      pj_coordinate = revision.revision_types_de_champ.first

      # check nested relationship
      expect(pj_coordinate.association(:revision).loaded?).to eq(true)
      expect(pj_coordinate.association(:procedure).loaded?).to eq(true)

      query_count = 0
      ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") do
        expect(pj_coordinate.type_de_champ.piece_justificative_template.blob).not_to be_nil
        expect(pj_coordinate.type_de_champ.notice_explicative.blob).to be_nil
      end

      expect(query_count).to eq(0)

      # check order
      original = Procedure.find(procedure.id)
      expect_relation_is_preloaded_sorted(original, procedure, :revision_types_de_champ)
      expect_relation_is_preloaded_sorted(original, procedure, :revision_types_de_champ_public)
      expect_relation_is_preloaded_sorted(original, procedure, :revision_types_de_champ_private)
      expect_relation_is_preloaded_sorted(original, procedure, :types_de_champ)
      expect_relation_is_preloaded_sorted(original, procedure, :root_types_de_champ_public)
      expect_relation_is_preloaded_sorted(original, procedure, :root_types_de_champ_private)
    end

    def expect_relation_is_preloaded_sorted(original, preloaded, association)
      expect(original.draft_revision.send(association).map(&:id)).to eq(preloaded.draft_revision.send(association).map(&:id))
    end
  end

  describe 'batch loading several revisions' do
    it 'gives each coordinate its own type de champ instance, so per-instance tree state cannot leak across revisions' do
      revisions = [procedure.published_revision, procedure.draft_revision]
      ProcedureRevisionPreloader.new(revisions).all

      published_tdc, draft_tdc = revisions.map { it.revision_types_de_champ.first.type_de_champ }

      expect(published_tdc.id).to eq(draft_tdc.id)
      expect(published_tdc).not_to equal(draft_tdc)
    end
  end
end
