# frozen_string_literal: true

RSpec.describe DossierChampsConcern do
  let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }
  let(:types_de_champ_public) do
    [
      { type: :text, libelle: "Un champ text", stable_id: 99 },
      { type: :text, libelle: "Un autre champ text", stable_id: 991 },
      { type: :yes_no, libelle: "Un champ yes no", stable_id: 992 },
      { type: :repetition, libelle: "Un champ répétable", stable_id: 993, mandatory: true, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
    ]
  end
  let(:types_de_champ_private) do
    [
      { type: :text, libelle: "Une annotation", stable_id: 995 },
    ]
  end
  let(:dossier) { create(:dossier, procedure:) }

  describe "#find_type_de_champ_by_stable_id(public)" do
    subject { dossier.find_type_de_champ_by_stable_id(992, :public) }

    it { is_expected.to be_truthy }
  end

  describe "#find_type_de_champ_by_stable_id(private)" do
    subject { dossier.find_type_de_champ_by_stable_id(995, :private) }

    it { is_expected.to be_truthy }
  end

  describe "#project_champ" do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
    let(:type_de_champ_private) { dossier.find_type_de_champ_by_stable_id(995) }

    context "public champ" do
      let(:row_id) { nil }
      subject { dossier.project_champ(type_de_champ_public, row_id:) }

      it { expect(subject.persisted?).to be_truthy }

      context "in repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { dossier.project_champ(type_de_champ_repetition).row_ids.first }

        it {
          expect(subject.new_record?).to be_truthy
          expect(subject.row_id).to eq(row_id)
        }

        context "invalid row_id" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
          it {
            expect { subject }.to raise_error("type_de_champ #{type_de_champ_public.stable_id} in revision #{dossier.revision_id} can not have a row_id because it is not part of a repetition")
          }
        end
      end

      context "missing champ" do
        before { dossier.champs.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it {
          expect(subject.new_record?).to be_truthy
          expect(subject.is_a?(Champs::TextChamp)).to be_truthy
          expect(subject.updated_at).not_to be_nil
        }

        context "in repetition" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
          let(:row_id) { ULID.generate }

          it {
            expect(subject.new_record?).to be_truthy
            expect(subject.is_a?(Champs::TextChamp)).to be_truthy
            expect(subject.row_id).to eq(row_id)
            expect(subject.updated_at).not_to be_nil
          }

          context "invalid row_id" do
            let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
            it {
              expect { subject }.to raise_error("type_de_champ #{type_de_champ_public.stable_id} in revision #{dossier.revision_id} can not have a row_id because it is not part of a repetition")
            }
          end
        end
      end
    end

    context "private champ" do
      subject { dossier.project_champ(type_de_champ_private) }

      it { expect(subject.persisted?).to be_truthy }

      context "missing champ" do
        before { dossier.champs.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it {
          expect(subject.new_record?).to be_truthy
          expect(subject.is_a?(Champs::TextChamp)).to be_truthy
          expect(subject.updated_at).not_to be_nil
        }
      end
    end

    context 'draft user stream' do
      let(:row_id) { nil }
      subject { dossier.with_update_stream(dossier.user).project_champ(type_de_champ_public, row_id:) }

      it { expect(subject.persisted?).to be_truthy }

      context "in repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { dossier.project_champ(type_de_champ_repetition).row_ids.first }

        it {
          expect(subject.new_record?).to be_truthy
          expect(subject.row_id).to eq(row_id)
        }
      end

      context "missing champ" do
        before { dossier.champs.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it {
          expect(subject.new_record?).to be_truthy
          expect(subject.is_a?(Champs::TextChamp)).to be_truthy
        }

        context "in repetition" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
          let(:row_id) { ULID.generate }

          it {
            expect(subject.new_record?).to be_truthy
            expect(subject.is_a?(Champs::TextChamp)).to be_truthy
            expect(subject.row_id).to eq(row_id)
          }
        end
      end
    end
  end

  describe '#project_champs_public' do
    subject { dossier.project_champs_public }

    it do
      expect(subject.size).to eq(4)
      expect(subject.find { _1.libelle == 'Nom' }).to be_falsey
    end
  end

  describe '#project_champs_private' do
    subject { dossier.project_champs_private }

    it { expect(subject.size).to eq(1) }
  end

  describe '#filled_champs_public' do
    let(:types_de_champ_public) do
      [
        { type: :header_section },
        { type: :text, libelle: "Un champ text" },
        { type: :text, libelle: "Un autre champ text" },
        { type: :yes_no, libelle: "Un champ yes no" },
        { type: :repetition, libelle: "Un champ répétable", mandatory: true, children: [{ type: :text, libelle: 'Nom' }] },
        { type: :explication },
      ]
    end
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    subject { dossier.filled_champs_public }

    it do
      expect(subject.size).to eq(5)
      expect(subject.filter { _1.libelle == 'Nom' }.size).to eq(2)
    end
  end

  describe '#filled_champs_private' do
    let(:types_de_champ_private) do
      [
        { type: :header_section },
        { type: :text, libelle: "Une annotation" },
        { type: :explication },
      ]
    end
    subject { dossier.filled_champs_private }

    it { expect(subject.size).to eq(1) }
  end

  describe '#repetition_row_ids' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    subject { dossier.repetition_row_ids(type_de_champ_repetition) }

    it { expect(subject.size).to eq(1) }

    context 'given a type de champ repetition in another revision' do
      before do
        procedure.draft_revision.remove_type_de_champ(type_de_champ_repetition.stable_id)
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { expect { subject }.not_to raise_error }
    end
  end

  describe '#project_rows_for' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    subject { dossier.project_rows_for(type_de_champ_repetition) }

    it do
      expect(subject.size).to eq(1)
      expect(subject.first.size).to eq(1)
    end
  end

  describe '#repetition_add_row' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:row_ids) { dossier.repetition_row_ids(type_de_champ_repetition) }
    subject { dossier.repetition_add_row(type_de_champ_repetition, updated_by: 'test') }

    it do
      expect { subject }.to change { dossier.repetition_row_ids(type_de_champ_repetition).size }.by(1)
      expect(subject).to be_in(row_ids)
    end
  end

  describe '#repetition_remove_row' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:row_id) { dossier.repetition_row_ids(type_de_champ_repetition).first }
    let(:row_ids) { dossier.repetition_row_ids(type_de_champ_repetition) }
    subject { dossier.repetition_remove_row(type_de_champ_repetition, row_id, updated_by: 'test') }

    it { expect { subject }.to change { dossier.repetition_row_ids(type_de_champ_repetition).size }.by(-1) }
    it { row_id; subject; expect(row_id).not_to be_in(row_ids) }
  end

  describe "#champ_values_for_export" do
    subject { dossier.champ_values_for_export(dossier.revision.types_de_champ_public, format: :xlsx) }

    it do
      expect(subject.size).to eq(4)
      expect(subject.first).to eq(["Un champ text", nil])
    end
  end

  describe "#champs_for_prefill" do
    subject { dossier.champs_for_prefill([991, 995]) }

    it {
      expect(subject.size).to eq(2)
      expect(subject.map(&:libelle)).to eq(["Une annotation", "Un autre champ text"])
      expect(subject.all?(&:persisted?)).to be_truthy
    }

    context "missing champ" do
      before { dossier; Champs::TextChamp.destroy_all }

      it {
        expect(subject.size).to eq(2)
        expect(subject.map(&:libelle)).to eq(["Une annotation", "Un autre champ text"])
        expect(subject.all?(&:persisted?)).to be_truthy
      }
    end
  end

  describe "#champ_for_update" do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
    let(:type_de_champ_private) { dossier.find_type_de_champ_by_stable_id(995) }
    let(:row_id) { nil }

    context "public champ" do
      subject { dossier.champ_for_update(type_de_champ_public, row_id:, updated_by: dossier.user.email) }

      it {
        expect(subject.persisted?).to be_truthy
        expect(subject.row_id).to eq(row_id)
      }

      context "in repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { ULID.generate }

        it {
          expect(subject.persisted?).to be_truthy
          expect(subject.row_id).to eq(row_id)
        }
      end

      context "missing champ" do
        before { dossier; Champs::TextChamp.destroy_all }

        it {
          expect(subject.persisted?).to be_truthy
          expect(subject.is_a?(Champs::TextChamp)).to be_truthy
        }

        context "in repetition" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
          let(:row_id) { ULID.generate }

          it {
            expect(subject.persisted?).to be_truthy
            expect(subject.is_a?(Champs::TextChamp)).to be_truthy
            expect(subject.row_id).to eq(row_id)
          }
        end
      end

      context "champ with type change" do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: "Un champ text", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:project_champ) { dossier.project_champ(type_de_champ_public) }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.update!(type_champ: TypeDeChamp.type_champs.fetch(:checkbox))
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it {
          expect(subject.persisted?).to be_truthy
          expect(subject.is_a?(Champs::CheckboxChamp)).to be_truthy
          expect(subject.value).to be_nil
          expect(project_champ.is_a?(Champs::CheckboxChamp)).to be_truthy
        }
      end

      context "champ carte" do
        let(:types_de_champ_public) { [{ type: :carte, libelle: "Un champ carte", stable_id: 996 }] }
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(996) }

        it {
          expect(subject.persisted?).to be_truthy
          expect(subject.is_a?(Champs::CarteChamp)).to be_truthy
          expect(subject.stream).to eq(Champ::MAIN_STREAM)
          expect(subject.geo_areas.size).to eq(0)
        }

        context 'user:buffer' do
          let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

          before do
            dossier.with_update_stream(dossier.user)
          end

          let(:main_champ) do
            dossier.with_main_stream do
              dossier.project_champ(type_de_champ_public)
            end
          end

          it {
            expect(subject.persisted?).to be_truthy
            expect(subject.is_a?(Champs::CarteChamp)).to be_truthy
            expect(subject.stream).to eq(Champ::USER_BUFFER_STREAM)
            expect(subject.geo_areas.size).to eq(2)
            expect(subject.geo_areas.size).to eq(main_champ.geo_areas.size)
            expect(subject.geo_areas.first.id).not_to eq(main_champ.geo_areas.first.id)
          }
        end
      end
    end

    context "private champ" do
      subject { dossier.champ_for_update(type_de_champ_private, row_id:, updated_by: dossier.user.email) }

      it {
        expect(subject.persisted?).to be_truthy
        expect(subject.row_id).to eq(row_id)
      }
    end
  end

  describe "#public_champ_for_update" do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:row_id) { ULID.generate }

    let(:attributes) do
      {
        "99" => { value: "Hello" },
        "991" => { value: "World" },
        "994-#{row_id}" => { value: "Greer" },
      }
    end

    let(:champ_99) { dossier.project_champ(dossier.find_type_de_champ_by_stable_id(99)) }
    let(:champ_991) { dossier.project_champ(dossier.find_type_de_champ_by_stable_id(991)) }
    let(:champ_994) { dossier.project_champ(dossier.find_type_de_champ_by_stable_id(994), row_id:) }

    def assign_champs_attributes(attributes)
      attributes.each do |public_id, attributes|
        champ = dossier.public_champ_for_update(public_id, updated_by: dossier.user.email)
        champ.assign_attributes(attributes)
      end
    end

    subject { assign_champs_attributes(attributes) }

    it {
      subject
      expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
      expect(champ_99.changed?).to be_truthy
      expect(champ_991.changed?).to be_truthy
      expect(champ_994.changed?).to be_truthy
      expect(champ_99.value).to eq("Hello")
      expect(champ_991.value).to eq("World")
      expect(champ_994.value).to eq("Greer")
    }

    context "missing champs" do
      before { dossier; Champs::TextChamp.destroy_all; }

      it {
        subject
        expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
        expect(champ_99.changed?).to be_truthy
        expect(champ_991.changed?).to be_truthy
        expect(champ_994.changed?).to be_truthy
        expect(champ_99.value).to eq("Hello")
        expect(champ_991.value).to eq("World")
        expect(champ_994.value).to eq("Greer")
      }
    end

    context "champ with type change" do
      context 'text -> linked_drop_down_list' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: "Un champ text", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:attributes) { { "99" => { primary_value: "primary" } } }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.update!(type_champ: TypeDeChamp.type_champs.fetch(:linked_drop_down_list), drop_down_options: ["--primary--", "secondary"])
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it {
          expect { subject }.to change { dossier.champs.find_by(stable_id: 99).last_write_type_champ }
            .from(TypeDeChamp.type_champs.fetch(:text))
            .to(TypeDeChamp.type_champs.fetch(:linked_drop_down_list))
          expect(champ_99.persisted?).to be_truthy
          expect(champ_99.last_write_type_champ).to eq(TypeDeChamp.type_champs.fetch(:linked_drop_down_list))
          expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
          expect(champ_99.changed?).to be_truthy
          expect(champ_99.value).to eq('["primary",""]')
        }
      end

      context 'textarea -> text' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :textarea, libelle: "Un champ textarea", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:attributes) { { "99" => { value: "test text" } } }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.update!(type_champ: TypeDeChamp.type_champs.fetch(:text))
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it {
          expect { subject }.to change { dossier.champs.find_by(stable_id: 99).last_write_type_champ }
            .from(TypeDeChamp.type_champs.fetch(:textarea))
            .to(TypeDeChamp.type_champs.fetch(:text))
          expect(champ_99.persisted?).to be_truthy
          expect(champ_99.last_write_type_champ).to eq(TypeDeChamp.type_champs.fetch(:text))
          expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
          expect(champ_99.changed?).to be_truthy
          expect(champ_99.value).to eq('test text')
        }
      end

      context 'yes_no -> checkbox' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :yes_no, libelle: "Un champ yes/no", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:attributes) { { "99" => { value: "true" } } }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.update!(type_champ: TypeDeChamp.type_champs.fetch(:checkbox))
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it {
          expect { subject }.to change { dossier.champs.find_by(stable_id: 99).last_write_type_champ }
            .from(TypeDeChamp.type_champs.fetch(:yes_no))
            .to(TypeDeChamp.type_champs.fetch(:checkbox))
          expect(champ_99.persisted?).to be_truthy
          expect(champ_99.last_write_type_champ).to eq(TypeDeChamp.type_champs.fetch(:checkbox))
          expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
          expect(champ_99.changed?).to be_truthy
          expect(champ_99.value).to eq('true')
        }
      end

      context 'regions -> text' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :regions, libelle: "Un champ regions", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:attributes) { { "99" => { value: "test text" } } }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.update!(type_champ: TypeDeChamp.type_champs.fetch(:text))
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it {
          expect { subject }.to change { dossier.champs.find_by(stable_id: 99).last_write_type_champ }
            .from(TypeDeChamp.type_champs.fetch(:regions))
            .to(TypeDeChamp.type_champs.fetch(:text))
          expect(champ_99.persisted?).to be_truthy
          expect(champ_99.last_write_type_champ).to eq(TypeDeChamp.type_champs.fetch(:text))
          expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
          expect(champ_99.changed?).to be_truthy
          expect(champ_99.value).to eq('test text')
        }
      end
    end
  end

  describe "#private_champ_for_update" do
    let(:attributes) do
      {
        "995" => { value: "Hello" },
      }
    end

    let(:annotation_995) { dossier.project_champ(dossier.find_type_de_champ_by_stable_id(995)) }

    def assign_champs_attributes(attributes)
      attributes.each do |public_id, attributes|
        champ = dossier.private_champ_for_update(public_id, updated_by: dossier.user.email)
        champ.assign_attributes(attributes)
      end
    end

    subject { assign_champs_attributes(attributes) }

    it {
      subject
      expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
      expect(annotation_995.changed?).to be_truthy
      expect(annotation_995.value).to eq("Hello")
    }

    context "missing champs" do
      before { dossier; Champs::TextChamp.destroy_all; }

      it {
        subject
        expect(dossier.champs.any?(&:changed_for_autosave?)).to be_truthy
        expect(annotation_995.changed?).to be_truthy
        expect(annotation_995.value).to eq("Hello")
      }
    end
  end

  context 'en_construction(user)' do
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    describe "#public_champ_for_update" do
      let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
      let(:row_ids) { dossier.project_champ(type_de_champ_repetition).row_ids }
      let(:row_id) { row_ids.first }

      let(:attributes) do
        {
          "99" => { value: "Hello" },
          "991" => { value: "World" },
          "994-#{row_id}" => { value: "Greer" },
        }
      end

      let(:new_attributes) do
        {
          "99" => { value: "Hello!!!" },
          "994-#{row_id}" => { value: "Greer is the best, for sure !" },
        }
      end

      let(:bad_attributes) do
        {
          "99" => { value: "bad" },
          "994-#{row_id}" => { value: "bad" },
        }
      end

      def main_champ(stable_id, row_id = nil)
        dossier.with_main_stream do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def draft_champ(stable_id, row_id = nil)
        dossier.with_update_stream(dossier.user) do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def main_champ_99 = main_champ(99)
      def main_champ_991 = main_champ(991)
      def main_champ_994 = main_champ(994, row_id)
      def draft_champ_99 = draft_champ(99)
      def draft_champ_991 = draft_champ(991)
      def draft_champ_994 = draft_champ(994, row_id)

      def assign_champs_attributes(attributes)
        attributes.each do |public_id, attributes|
          champ = dossier.public_champ_for_update(public_id, updated_by: dossier.user.email)
          champ.assign_attributes(attributes)
        end
      end

      subject do
        dossier.with_update_stream(dossier.user) { assign_champs_attributes(attributes) }
      end

      it {
        subject
        dossier.save!

        expect(dossier.user_buffer_changes?).to be_truthy

        expect(main_champ_99.stream).to eq(Champ::MAIN_STREAM)
        expect(main_champ_991.stream).to eq(Champ::MAIN_STREAM)
        expect(main_champ_994.stream).to eq(Champ::MAIN_STREAM)

        expect(main_champ_99.value).to be_nil
        expect(main_champ_991.value).to be_nil
        expect(main_champ_994.value).to be_nil

        expect(draft_champ_99.stream).to eq(Champ::USER_BUFFER_STREAM)
        expect(draft_champ_991.stream).to eq(Champ::USER_BUFFER_STREAM)
        expect(draft_champ_994.stream).to eq(Champ::USER_BUFFER_STREAM)

        expect(draft_champ_99.value).to eq("Hello")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("Greer")
        expect(dossier.history.size).to eq(0)

        dossier.merge_user_buffer_stream!

        expect(main_champ_99.value).to eq("Hello")
        expect(main_champ_991.value).to eq("World")
        expect(main_champ_994.value).to eq("Greer")
        expect(dossier.history.size).to eq(2)

        travel_to(1.hour.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(new_attributes) }
          dossier.save!
          dossier.merge_user_buffer_stream!
        end

        expect(main_champ_99.value).to eq("Hello!!!")
        expect(main_champ_994.value).to eq("Greer is the best, for sure !")
        expect(dossier.history.size).to eq(4)

        travel_to(2.hours.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(bad_attributes) }
          dossier.save!
        end

        expect(draft_champ_99.value).to eq("bad")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("bad")
        dossier.reset_user_buffer_stream!
        expect(draft_champ_99.value).to eq("Hello!!!")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("Greer is the best, for sure !")
      }

      context "missing champs" do
        before { dossier; Champs::TextChamp.destroy_all; dossier.champs.reload }

        it {
          subject
          dossier.save!

          expect(draft_champ_99.stream).to eq(Champ::USER_BUFFER_STREAM)
          expect(draft_champ_991.stream).to eq(Champ::USER_BUFFER_STREAM)
          expect(draft_champ_994.stream).to eq(Champ::USER_BUFFER_STREAM)

          expect(draft_champ_99.value).to eq("Hello")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer")

          expect(dossier.history.size).to eq(0)
          dossier.merge_user_buffer_stream!
          expect(dossier.history.size).to eq(0)
        }
      end

      context "piece_justificative or titre_identite" do
        let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
        let(:types_de_champ_public) do
          [
            { type: :piece_justificative, libelle: "Un champ pj", stable_id: 98 },
            { type: :titre_identite, libelle: "Un champ titre identite", stable_id: 99 },
          ]
        end

        subject do
          dossier.with_update_stream(dossier.user) do
            champ = dossier.public_champ_for_update('98', updated_by: dossier.user.email)
            champ.piece_justificative_file.attach({ io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf' })
            champ.save!
            champ = dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            champ.piece_justificative_file.purge
          end
        end

        it {
          subject

          expect(dossier.history.size).to eq(0)
          dossier.merge_user_buffer_stream!
          perform_enqueued_jobs
          dossier.reload
          expect(dossier.history.size).to eq(2)
          dossier.clean_champs_after_instruction!
          dossier.reload

          expect(dossier.history.size).to eq(2)
          expect(dossier.history.map(&:piece_justificative_file).map { [_1.record.type, _1.attached?] }).to match_array([['Champs::PieceJustificativeChamp', true], ['Champs::TitreIdentiteChamp', false]])

          pj_champ = dossier.project_champ(dossier.find_type_de_champ_by_stable_id(98), row_id: nil)
          expect(pj_champ.piece_justificative_file.size).to eq(2)
          expect(pj_champ.piece_justificative_file.map(&:filename).map(&:to_s)).to eq(['toto.txt', 'Contrat.pdf'])
        }
      end
    end

    describe "#repetition_remove_row" do
      let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
      let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
      let(:row_ids) { dossier.project_champ(type_de_champ_repetition).row_ids }
      let(:row_id) { row_ids.first }

      def main_row(stable_id, row_id)
        dossier.with_main_stream do
          dossier.send(:champs_on_stream).find { _1.stable_id == stable_id && _1.row_id == row_id }
        end
      end

      def draft_row(stable_id, row_id)
        dossier.with_update_stream(dossier.user) do
          dossier.send(:champs_on_stream).find { _1.stable_id == stable_id && _1.row_id == row_id }
        end
      end

      def main_champ_993 = main_row(993, row_id)
      def draft_champ_993 = draft_row(993, row_id)

      subject do
        dossier.with_update_stream(dossier.user) { dossier.repetition_remove_row(type_de_champ_repetition, row_id, updated_by: 'test') }
      end

      it {
        expect(main_champ_993.discarded_at).to be_nil
        subject
        expect(main_champ_993.discarded_at).to be_nil
        expect(draft_champ_993.discarded_at).not_to be_nil

        dossier.reload
        dossier.merge_user_buffer_stream!
        dossier.reload

        expect(dossier.history.size).to eq(2)

        dossier.clean_champs_after_submit!
        dossier.reload

        expect(dossier.history.map(&:public_id)).to match_array(["993-#{row_id}", "994-#{row_id}"])
      }
    end
  end

  context 'en_construction(instructeur)' do
    let(:dossier) { create(:dossier, procedure:) }

    describe "#public_champ_for_update" do
      let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
      let(:row_ids) { dossier.project_champ(type_de_champ_repetition).row_ids }
      let(:row_id) { row_ids.first }

      let(:user_attributes_0) do
        {
          "99" => { value: "Bonjour" },
          "991" => { value: "Au revoir" },
        }
      end

      let(:attributes_0) do
        {
          "99" => { value: "Hello" },
          "991" => { value: "World" },
          "994-#{row_id}" => { value: "Greer" },
        }
      end

      let(:attributes_1) do
        {
          "99" => { value: "Hello!!!" },
          "994-#{row_id}" => { value: "Greer is the best, for sure !" },
        }
      end

      let(:user_attributes_1) do
        { "99" => { value: "Hello???" } }
      end

      let(:attributes_2) do
        { "99" => { value: "Hello..." } }
      end

      let(:bad_attributes) do
        {
          "99" => { value: "bad" },
          "994-#{row_id}" => { value: "bad" },
        }
      end

      def main_champ(stable_id, row_id = nil)
        dossier.with_main_stream do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def draft_champ(stable_id, row_id = nil)
        dossier.with_instructeur_buffer_stream do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def user_draft_champ(stable_id, row_id = nil)
        dossier.with_update_stream(dossier.user) do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def user_history_champ(stable_id, row_id = nil)
        dossier.with_user_history_stream do
          dossier.project_champ(dossier.find_type_de_champ_by_stable_id(stable_id), row_id:)
        end
      end

      def main_champ_99 = main_champ(99)
      def main_champ_991 = main_champ(991)
      def main_champ_994 = main_champ(994, row_id)
      def draft_champ_99 = draft_champ(99)
      def draft_champ_991 = draft_champ(991)
      def draft_champ_994 = draft_champ(994, row_id)
      def user_draft_champ_99 = user_draft_champ(99)
      def user_history_champ_99 = user_history_champ(99)
      def user_history_champ_991 = user_history_champ(991)
      def user_history_champ_994 = user_history_champ(994, row_id)

      def assign_champs_attributes(attributes)
        attributes.each do |public_id, attributes|
          champ = dossier.public_champ_for_update(public_id, updated_by: dossier.user.email)
          champ.assign_attributes(attributes)
        end
      end

      subject do
        assign_champs_attributes(user_attributes_0)
        dossier.save!
        dossier.passer_en_construction!
        dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_0) }
      end

      it {
        subject
        dossier.save!

        expect(dossier.instructeur_buffer_changes?).to be_truthy

        expect(main_champ_99.stream).to eq(Champ::MAIN_STREAM)
        expect(main_champ_991.stream).to eq(Champ::MAIN_STREAM)
        expect(main_champ_994.stream).to eq(Champ::MAIN_STREAM)

        expect(main_champ_99.value).to eq('Bonjour')
        expect(main_champ_991.value).to eq('Au revoir')
        expect(main_champ_994.value).to be_nil

        expect(draft_champ_99.stream).to eq(Champ::INSTRUCTEUR_BUFFER_STREAM)
        expect(draft_champ_991.stream).to eq(Champ::INSTRUCTEUR_BUFFER_STREAM)
        expect(draft_champ_994.stream).to eq(Champ::INSTRUCTEUR_BUFFER_STREAM)

        expect(draft_champ_99.value).to eq("Hello")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("Greer")
        expect(dossier.history.size).to eq(0)

        dossier.merge_instructeur_buffer_stream!
        dossier.champs.reload

        expect(main_champ_99.value).to eq("Hello")
        expect(main_champ_991.value).to eq("World")
        expect(main_champ_994.value).to eq("Greer")
        expect(dossier.history.size).to eq(2)

        travel_to(10.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_1) }
          dossier.save!
        end

        expect(draft_champ_99.value).to eq("Hello!!!")
        expect(draft_champ_994.value).to eq("Greer is the best, for sure !")

        travel_to(20.minutes.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(user_attributes_1) }
          dossier.save!

          # main stream value
          expect(main_champ_99.value).to eq("Hello")
          # instructeur stream value
          expect(draft_champ_99.value).to eq("Hello!!!")
          # user stream value
          expect(user_draft_champ_99.value).to eq("Hello???")

          dossier.merge_user_buffer_stream!
          dossier.touch(:en_construction_at)
          dossier.champs.reload
        end

        expect(draft_champ_99.value).to eq("Hello???")
        expect(main_champ_99.value).to eq("Hello???")
        expect(main_champ_994.value).to eq("Greer")
        expect(dossier.history.size).to eq(3)

        travel_to(30.minutes.from_now) do
          dossier.merge_instructeur_buffer_stream!
          dossier.champs.reload
        end

        expect(main_champ_99.value).to eq("Hello???")
        expect(main_champ_994.value).to eq("Greer is the best, for sure !")
        expect(dossier.history.size).to eq(4)

        travel_to(40.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(bad_attributes) }
          dossier.save!
        end

        expect(draft_champ_99.value).to eq("bad")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("bad")
        dossier.reset_instructeur_buffer_stream!
        expect(draft_champ_99.value).to eq("Hello???")
        expect(draft_champ_991.value).to eq("World")
        expect(draft_champ_994.value).to eq("Greer is the best, for sure !")

        travel_to(40.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_2) }
          dossier.save!
          dossier.merge_instructeur_buffer_stream!
          dossier.champs.reload
        end

        expect(main_champ_99.value).to eq("Hello...")
        expect(main_champ_991.value).to eq("World")
        expect(main_champ_994.value).to eq("Greer is the best, for sure !")

        expect(user_history_champ_99.value).to eq("Hello???")
        expect(user_history_champ_991.value).to eq("World")
        expect(user_history_champ_994.value).to eq("Greer")
      }
    end
  end

  describe '#set_default_value_for_france_connect_champs' do
    let!(:procedure) { create(:procedure, :published, types_de_champ_public:, for_individual: true) }
    let(:types_de_champ_public) { [{ type: :quotient_familial }] }
    let(:dossier) { create(:dossier, procedure:, for_procedure_preview: false, for_tiers: false) }
    let(:champ_qf) { dossier.champs.first }
    let!(:fci) { create(:france_connect_information, user: dossier.user) }

    subject { dossier.set_default_value_for_france_connect_champs }

    context 'when the user starts a new dossier' do
      before { allow(champ_qf).to receive(:fetch!).and_return(nil) }
      it 'set a default value for the quotient_familial champ' do
        subject
        expect(champ_qf).to have_received(:fetch!)
      end
    end

    context "when the user returns to their dossier" do
      before do
        champ_qf.update(external_state: 'fetched')
        dossier.reload
        allow(champ_qf).to receive(:fetch!).and_return(nil)
      end

      it 'does not attempt to set the champ again' do
        subject
        expect(champ_qf).not_to have_received(:fetch!)
      end
    end

    context 'when the admin add a new quotient_familial tdc' do
      before do
        champ_qf.update(external_state: 'fetched')
        procedure.draft_revision.add_type_de_champ({
          type_champ: TypeDeChamp.type_champs.fetch(:quotient_familial),
          libelle: "QF 2",
        })
        procedure.publish_revision!(procedure.administrateurs.first)
        dossier.reload
        dossier.rebase!

        @old_qf = dossier.project_champs_public.last
        @new_qf = dossier.project_champs_public.first

        @fetched_instances = []

        allow_any_instance_of(Champs::QuotientFamilialChamp)
          .to receive(:fetch!) do |instance|
            @fetched_instances << instance
            nil
          end
      end

      it 'does not attempt to set the old champ again, but does attempt to set the new champ' do
        subject
        fetched_ids = @fetched_instances.map(&:stable_id)
        expect(fetched_ids).to include(@new_qf.stable_id)
        expect(fetched_ids).not_to include(@old_qf.stable_id)
      end
    end
  end
end
