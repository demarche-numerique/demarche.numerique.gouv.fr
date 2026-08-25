# frozen_string_literal: true

RSpec.describe DossierChampsConcern do
  # Defined as methods (not `let`) so `let_it_be` can call them from its
  # before_all context, while nested contexts can still shadow them with `let`.
  def public_default_type_de_champs
    [
      { type: :text, libelle: "Un champ text", stable_id: 99 },
      { type: :text, libelle: "Un autre champ text", stable_id: 991 },
      { type: :yes_no, libelle: "Un champ yes no", stable_id: 992 },
      { type: :repetition, libelle: "Un champ répétable", stable_id: 993, mandatory: true, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
    ]
  end

  def private_default_type_de_champs
    [
      { type: :text, libelle: "Une annotation", stable_id: 995 },
    ]
  end

  # Building this procedure and its dossier costs ~130ms, and most examples
  # want the exact same shape, so they are built once for the whole file.
  # `refind` (rather than `reload`) is required: these examples leave state on
  # the instance that a reload would not clear — `with_update_stream(user)`
  # without a block pins @stream, and champ_data association targets are
  # reassigned in place.
  let_it_be(:default_procedure, refind: true) do
    create(:procedure, public_type_de_champs: public_default_type_de_champs, private_type_de_champs: private_default_type_de_champs)
  end
  let_it_be(:default_dossier, refind: true) { create(:dossier, procedure: default_procedure) }

  let(:public_type_de_champs) { public_default_type_de_champs }
  let(:private_type_de_champs) { private_default_type_de_champs }

  # Contexts that override the champ lists (or `procedure`/`dossier`
  # themselves) build their own records; everyone else shares the default.
  let(:procedure) do
    if [public_type_de_champs, private_type_de_champs] == [public_default_type_de_champs, private_default_type_de_champs]
      default_procedure
    else
      create(:procedure, public_type_de_champs:, private_type_de_champs:)
    end
  end
  let(:dossier) { procedure == default_procedure ? default_dossier : create(:dossier, procedure:) }

  # Mirrors how the champs controller assigns a form payload: one
  # champ_for_update per public_id, then assign_attributes on the result.
  def assign_champs_attributes(attributes, scope: :public)
    attributes.each do |public_id, champ_attributes|
      champ = if scope == :private
        dossier.private_champ_for_update(public_id, updated_by: dossier.user.email)
      else
        dossier.public_champ_for_update(public_id, updated_by: dossier.user.email)
      end

      champ.assign_attributes(champ_attributes)
    end
  end

  describe "#find_type_de_champ_by_stable_id" do
    it "finds a public type de champ" do
      expect(dossier.find_type_de_champ_by_stable_id(992, :public).libelle).to eq("Un champ yes no")
    end

    it "finds a private type de champ" do
      expect(dossier.find_type_de_champ_by_stable_id(995, :private).libelle).to eq("Une annotation")
    end

    it "searches the whole revision when no scope is given" do
      expect(dossier.find_type_de_champ_by_stable_id(992).libelle).to eq("Un champ yes no")
      expect(dossier.find_type_de_champ_by_stable_id(995).libelle).to eq("Une annotation")
    end

    it "does not find a champ outside the requested scope" do
      expect(dossier.find_type_de_champ_by_stable_id(995, :public)).to be_nil
      expect(dossier.find_type_de_champ_by_stable_id(992, :private)).to be_nil
    end

    it "accepts a stable id given as a string, as public_id parsing produces" do
      expect(dossier.find_type_de_champ_by_stable_id("992", :public).libelle).to eq("Un champ yes no")
    end

    it "returns nil for an unknown stable id" do
      expect(dossier.find_type_de_champ_by_stable_id(1234567)).to be_nil
    end
  end

  describe "#stable_id_in_revision?" do
    it "accepts an integer or a string, and rejects an unknown stable id" do
      expect(dossier.stable_id_in_revision?(99)).to be(true)
      expect(dossier.stable_id_in_revision?("99")).to be(true)
      expect(dossier.stable_id_in_revision?(1234567)).to be(false)
    end
  end

  describe "#project_champ" do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
    let(:type_de_champ_private) { dossier.find_type_de_champ_by_stable_id(995) }

    context "public champ" do
      let(:row_id) { nil }
      subject { dossier.project_champ(type_de_champ_public, row_id:) }

      it { is_expected.to be_persisted }

      context "in repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { dossier.project_champ(type_de_champ_repetition).row_ids.first }

        it "projects a new record carrying the row_id" do
          expect(subject).to be_new_record
          expect(subject.row_id).to eq(row_id)
        end
      end

      context "with a row_id on a champ outside any repetition" do
        let(:row_id) { ULID.generate }

        it "raises" do
          expect { subject }.to raise_error("type_de_champ #{type_de_champ_public.stable_id} in revision #{dossier.revision_id} can not have a row_id because it is not part of a repetition")
        end
      end

      context "without a row_id on a champ inside a repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { nil }

        it "raises" do
          expect { subject }.to raise_error("type_de_champ 994 in revision #{dossier.revision_id} must have a row_id because it is part of a repetition")
        end
      end

      context "missing champ" do
        before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it "builds a new champ of the right type with a fallback updated_at" do
          expect(subject).to be_new_record
          expect(subject).to be_a(Champs::TextChamp)
          expect(subject.updated_at).not_to be_nil
        end

        context "in repetition" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
          let(:row_id) { ULID.generate }

          it "builds a new champ carrying the row_id" do
            expect(subject).to be_new_record
            expect(subject).to be_a(Champs::TextChamp)
            expect(subject.row_id).to eq(row_id)
            expect(subject.updated_at).not_to be_nil
          end
        end
      end
    end

    context "private champ" do
      subject { dossier.project_champ(type_de_champ_private) }

      it { is_expected.to be_persisted }

      context "missing champ" do
        before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it "builds a new champ of the right type with a fallback updated_at" do
          expect(subject).to be_new_record
          expect(subject).to be_a(Champs::TextChamp)
          expect(subject.updated_at).not_to be_nil
        end
      end
    end

    context 'draft user stream' do
      let(:row_id) { nil }
      subject { dossier.with_update_stream(dossier.user).project_champ(type_de_champ_public, row_id:) }

      it { is_expected.to be_persisted }

      context "in repetition" do
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
        let(:row_id) { dossier.project_champ(type_de_champ_repetition).row_ids.first }

        it "projects a new record carrying the row_id" do
          expect(subject).to be_new_record
          expect(subject.row_id).to eq(row_id)
        end
      end

      context "missing champ" do
        before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all; dossier.reload }

        it "builds a new champ of the right type" do
          expect(subject).to be_new_record
          expect(subject).to be_a(Champs::TextChamp)
        end

        context "in repetition" do
          let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(994) }
          let(:row_id) { ULID.generate }

          it "builds a new champ carrying the row_id" do
            expect(subject).to be_new_record
            expect(subject).to be_a(Champs::TextChamp)
            expect(subject.row_id).to eq(row_id)
          end
        end
      end
    end
  end

  describe '#root_champs_public' do
    subject { dossier.root_champs_public }

    it "returns the root champs only, without repetition children" do
      expect(subject.map(&:libelle)).to eq(["Un champ text", "Un autre champ text", "Un champ yes no", "Un champ répétable"])
      expect(subject.map(&:libelle)).not_to include('Nom')
    end
  end

  describe '#root_champs_private' do
    subject { dossier.root_champs_private }

    it { expect(subject.map(&:libelle)).to eq(["Une annotation"]) }
  end

  describe '#champs' do
    subject { dossier.champs }

    it "concatenates public and private root champs" do
      expect(subject).to eq(dossier.root_champs_public + dossier.root_champs_private)
    end
  end

  describe '#flat_champs_public' do
    subject { dossier.flat_champs_public }

    it "inlines the repetition children after their repetition" do
      expect(subject.map(&:libelle)).to eq(["Un champ text", "Un autre champ text", "Un champ yes no", "Un champ répétable", "Nom"])
    end
  end

  describe '#flat_champs_private' do
    subject { dossier.flat_champs_private }

    it { expect(subject.map(&:libelle)).to eq(["Une annotation"]) }
  end

  describe '#filled_champs_public' do
    let(:public_type_de_champs) do
      [
        { type: :header_section, stable_id: 9001 },
        { type: :text, libelle: "Un champ text", stable_id: 9002 },
        { type: :text, libelle: "Un autre champ text", stable_id: 9003 },
        { type: :yes_no, libelle: "Un champ yes no", stable_id: 9004 },
        { type: :repetition, libelle: "Un champ répétable", stable_id: 9005, mandatory: true, children: [{ type: :text, libelle: 'Nom', stable_id: 9006 }] },
        { type: :explication, stable_id: 9007 },
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
    let(:private_type_de_champs) do
      [
        { type: :header_section, stable_id: 9011 },
        { type: :text, libelle: "Une annotation", stable_id: 9012 },
        { type: :explication, stable_id: 9013 },
      ]
    end
    subject { dossier.filled_champs_private }

    it { expect(subject.size).to eq(1) }
  end

  describe '#repetition_row_ids' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    subject { dossier.repetition_row_ids(type_de_champ_repetition) }

    it { expect(subject.size).to eq(1) }

    it "returns [] for a type de champ that is not a repetition" do
      expect(dossier.repetition_row_ids(dossier.find_type_de_champ_by_stable_id(99))).to eq([])
    end

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

    it "returns one row of one child champ" do
      expect(subject.size).to eq(1)
      expect(subject.first.map(&:libelle)).to eq(['Nom'])
    end

    it "returns [] for a type de champ that is not a repetition" do
      expect(dossier.project_rows_for(dossier.find_type_de_champ_by_stable_id(99))).to eq([])
    end
  end

  describe '#repetition_rows_for_export' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    subject { dossier.repetition_rows_for_export(type_de_champ_repetition) }

    it "wraps each row id in a Row numbered from 1" do
      expect(subject.size).to eq(1)
      expect(subject.map(&:index)).to eq([1])
      expect(subject.map(&:row_id)).to eq(dossier.repetition_row_ids(type_de_champ_repetition))
      expect(subject.map(&:dossier)).to eq([dossier])
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

    it "raises when the type de champ is not a repetition" do
      expect { dossier.repetition_add_row(dossier.find_type_de_champ_by_stable_id(99), updated_by: 'test') }
        .to raise_error("Can't add row to non-repetition type de champ")
    end
  end

  describe '#repetition_remove_row' do
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:row_id) { dossier.repetition_row_ids(type_de_champ_repetition).first }
    let(:row_ids) { dossier.repetition_row_ids(type_de_champ_repetition) }
    subject { dossier.repetition_remove_row(type_de_champ_repetition, row_id, updated_by: 'test') }

    it { expect { subject }.to change { dossier.repetition_row_ids(type_de_champ_repetition).size }.by(-1) }
    it { row_id; subject; expect(row_id).not_to be_in(row_ids) }

    it "raises when the type de champ is not a repetition" do
      expect { dossier.repetition_remove_row(dossier.find_type_de_champ_by_stable_id(99), row_id, updated_by: 'test') }
        .to raise_error("Can't remove row from non-repetition type de champ")
    end
  end

  describe "#champ_values_for_export" do
    subject { dossier.champ_values_for_export(dossier.revision.public_root_type_de_champs, format: :xlsx) }

    # An empty yes_no exports as "" where the other types export nil.
    it "returns one [libelle, value] pair per root champ" do
      expect(subject).to eq([
        ["Un champ text", nil],
        ["Un autre champ text", nil],
        ["Un champ yes no", ""],
        ["Un champ répétable", nil],
      ])
    end
  end

  describe "#champs_for_prefill" do
    subject { dossier.champs_for_prefill([991, 995]) }

    # Order follows the revision's coordinates, where public and private
    # positions both start at zero: assert on the set, not the sequence.
    it {
      expect(subject.map(&:libelle)).to contain_exactly("Une annotation", "Un autre champ text")
      expect(subject.all?(&:persisted?)).to be_truthy
    }

    it "returns the repetition itself, not its children, and skips children asked for directly" do
      champs = dossier.champs_for_prefill([993, 994])

      expect(champs.map(&:libelle)).to eq(["Un champ répétable"])
    end

    context "missing champ" do
      before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all }

      it {
        expect(subject.map(&:libelle)).to contain_exactly("Une annotation", "Un autre champ text")
        expect(subject.all?(&:persisted?)).to be_truthy
      }
    end
  end

  describe "write guards" do
    let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(99) }
    let(:type_de_champ_private) { dossier.find_type_de_champ_by_stable_id(995) }
    let(:type_de_champ_repetition) { dossier.find_type_de_champ_by_stable_id(993) }
    let(:type_de_champ_repetition_child) { dossier.find_type_de_champ_by_stable_id(994) }

    context "when the dossier is en_construction" do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      it "refuses to write a public champ to the main stream" do
        expect { dossier.champ_for_update(type_de_champ_public, updated_by: 'test') }
          .to raise_error('Can not write to "main" stream on a dossier "en construction"')
      end

      it "allows writing a public champ on a buffer stream" do
        expect { dossier.with_update_stream(dossier.user) { dossier.champ_for_update(type_de_champ_public, updated_by: 'test') } }
          .not_to raise_error
      end

      it "refuses to write a private champ to a buffer stream" do
        expect { dossier.with_instructeur_buffer_stream { dossier.champ_for_update(type_de_champ_private, updated_by: 'test') } }
          .to raise_error('Can not write a private champ to "instructeur:buffer" stream')
      end

      it "allows writing a private champ to the main stream" do
        expect { dossier.champ_for_update(type_de_champ_private, updated_by: 'test') }.not_to raise_error
      end
    end

    it "refuses to write a repetition without a row_id" do
      expect { dossier.champ_for_update(type_de_champ_repetition, updated_by: 'test') }
        .to raise_error("type_de_champ 993 in revision #{dossier.revision_id} must have a row_id because it represents a row in a repetition")
    end

    it "refuses to write a repetition child without a row_id" do
      expect { dossier.champ_for_update(type_de_champ_repetition_child, updated_by: 'test') }
        .to raise_error("type_de_champ 994 in revision #{dossier.revision_id} must have a row_id because it is part of a repetition")
    end

    it "refuses to write a row_id on a champ outside any repetition" do
      expect { dossier.champ_for_update(type_de_champ_public, row_id: ULID.generate, updated_by: 'test') }
        .to raise_error("type_de_champ 99 in revision #{dossier.revision_id} can not have a row_id because it is not part of a repetition")
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
        before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all }

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
        let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: "Un champ text", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:project_champ) { dossier.project_champ(type_de_champ_public) }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99)
          tdc.becomes_type(TypesDeChamp::Checkbox.name).save!
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

        context "when the previous champ had fetched external data" do
          before do
            dossier.champ_data.first.update_columns(external_state: 'fetched', data: { 'title' => 'stale' })
          end

          it "resets the external state along with the data (RAILS-MAN)" do
            expect(subject.idle?).to be(true)
            expect(subject.data).to be_nil
            expect(subject.fetched?).to be(false)
          end
        end
      end

      # Rows persisted before value normalization moved from before_validation
      # to assignment time (74f2ba6da4) can hold values the current parser
      # rejects; they are never re-normalized on load. The upsert save must
      # self-heal them instead of tripping the iso_8601 validation before the
      # caller has assigned anything (RAILS-MC5).
      [
        { type: :date, legacy_value: '2021-06-31T00:00:00' },
        { type: :datetime, legacy_value: '12/06/2026 à 14h' },
      ].each do |row|
        type, legacy_value = row.values_at(:type, :legacy_value)

        context "#{type} champ with a legacy non-ISO value" do
          let(:public_type_de_champs) { [{ type:, libelle: "Un champ #{type}", stable_id: 99 }] }

          before do
            dossier.champ_for_update(type_de_champ_public, updated_by: dossier.user.email)
            # Raw SQL fragment: a hash through update_all/update_column would
            # run the value normalizer and defeat the simulation.
            dossier.champ_data.where(stable_id: 99).update_all(["value = ?", legacy_value])
            dossier.reload
          end

          it "drops the legacy value and returns the champ" do
            champ = subject
            expect(champ.value).to be_nil
            expect(champ.reload.value).to be_nil
          end
        end
      end

      context "champ carte" do
        let(:public_type_de_champs) { [{ type: :carte, libelle: "Un champ carte", stable_id: 996 }] }
        let(:type_de_champ_public) { dossier.find_type_de_champ_by_stable_id(996) }

        it {
          expect(subject.persisted?).to be_truthy
          expect(subject.is_a?(Champs::CarteChamp)).to be_truthy
          expect(subject.stream).to eq(Dossier::MAIN_STREAM)
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
            expect(subject.stream).to eq(Dossier::USER_BUFFER_STREAM)
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

    subject { assign_champs_attributes(attributes) }

    it {
      subject
      expect(dossier.champ_data.any?(&:changed_for_autosave?)).to be_truthy
      expect(champ_99.changed?).to be_truthy
      expect(champ_991.changed?).to be_truthy
      expect(champ_994.changed?).to be_truthy
      expect(champ_99.value).to eq("Hello")
      expect(champ_991.value).to eq("World")
      expect(champ_994.value).to eq("Greer")
      expect(champ_99.source_stream).to be_nil
    }

    context "missing champs" do
      before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all }

      it {
        subject
        expect(dossier.champ_data.any?(&:changed_for_autosave?)).to be_truthy
        expect(champ_99.changed?).to be_truthy
        expect(champ_991.changed?).to be_truthy
        expect(champ_994.changed?).to be_truthy
        expect(champ_99.value).to eq("Hello")
        expect(champ_991.value).to eq("World")
        expect(champ_994.value).to eq("Greer")
      }
    end

    # A published revision changing a champ's type must rewrite the existing
    # champ data in place: same stable_id, new class, new last_write_type_champ.
    # Each row is (from type, to type, assigned attributes, resulting value).
    [
      { from: :text,     to: :linked_drop_down_list, assign: { primary_value: "primary" }, value: '["primary",""]', to_params: { drop_down_options: ["--primary--", "secondary"] } },
      { from: :textarea, to: :text,                  assign: { value: "test text" },       value: 'test text' },
      { from: :text,     to: :date,                  assign: { value: "2026-08-03" },      value: '2026-08-03' },
      { from: :yes_no,   to: :checkbox,              assign: { value: "true" },            value: 'true' },
      { from: :regions,  to: :text,                  assign: { value: "test text" },       value: 'test text' },
    ].each do |row|
      from, to, assign, value = row.values_at(:from, :to, :assign, :value)
      to_params = row.fetch(:to_params, {})

      context "champ with type change #{from} -> #{to}" do
        let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: from, libelle: "Un champ #{from}", stable_id: 99 }]) }
        let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
        let(:attributes) { { "99" => assign } }

        before do
          tdc = dossier.procedure.draft_revision.find_and_ensure_exclusive_use(99).becomes_type(TypeDeChamp.class_for(to).name)
          tdc.update!(to_params)
          dossier.procedure.publish_revision!(procedure.administrateurs.first)
          perform_enqueued_jobs
          dossier.reload
        end

        it "rewrites the champ data as a #{to} champ" do
          expect { subject }.to change { dossier.champ_data.find_by(stable_id: 99).last_write_type_champ }
            .from(TypeDeChamp.type_champs.fetch(from))
            .to(TypeDeChamp.type_champs.fetch(to))
          expect(champ_99).to be_persisted
          expect(champ_99.last_write_type_champ).to eq(TypeDeChamp.type_champs.fetch(to))
          expect(dossier.champ_data.any?(&:changed_for_autosave?)).to be_truthy
          expect(champ_99).to be_changed
          expect(champ_99.value).to eq(value)
        end
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

    subject { assign_champs_attributes(attributes, scope: :private) }

    it {
      subject
      expect(dossier.champ_data.any?(&:changed_for_autosave?)).to be_truthy
      expect(annotation_995.changed?).to be_truthy
      expect(annotation_995.value).to eq("Hello")
    }

    context "missing champs" do
      before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all }

      it {
        subject
        expect(dossier.champ_data.any?(&:changed_for_autosave?)).to be_truthy
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

      subject do
        dossier.with_update_stream(dossier.user) { assign_champs_attributes(attributes) }
      end

      # Each phase happens at a distinct virtual time on purpose: champ data is
      # deduplicated by taking the most recent updated_at per public_id, and
      # `sort_by` is not stable, so rows sharing an updated_at would resolve
      # arbitrarily. Do not collapse the travel_to blocks.
      it "buffers user edits, merges them into main, and can be reset to the last merge" do
        subject
        dossier.save!

        aggregate_failures "user edits stay on the buffer stream" do
          expect(dossier.user_buffer_changes?).to be_truthy

          expect(main_champ_99.stream).to eq(Dossier::MAIN_STREAM)
          expect(main_champ_991.stream).to eq(Dossier::MAIN_STREAM)
          expect(main_champ_994.stream).to eq(Dossier::MAIN_STREAM)
          expect(main_champ_99.source_stream).to be_nil

          expect(main_champ_99.value).to be_nil
          expect(main_champ_991.value).to be_nil
          expect(main_champ_994.value).to be_nil

          expect(draft_champ_99.stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(draft_champ_991.stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(draft_champ_994.stream).to eq(Dossier::USER_BUFFER_STREAM)

          expect(draft_champ_99.value).to eq("Hello")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer")
          expect(dossier.history.size).to eq(0)
        end

        dossier.merge_user_buffer_stream!

        aggregate_failures "the first merge promotes the buffer to main" do
          expect(main_champ_99.value).to eq("Hello")
          expect(main_champ_991.value).to eq("World")
          expect(main_champ_994.value).to eq("Greer")
          expect(dossier.history.size).to eq(2)
        end

        travel_to(1.hour.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(new_attributes) }
          dossier.save!
          dossier.merge_user_buffer_stream!
        end

        aggregate_failures "a second merge archives the previous main values" do
          expect(main_champ_99.value).to eq("Hello!!!")
          expect(main_champ_994.value).to eq("Greer is the best, for sure !")
          expect(dossier.history.size).to eq(4)
        end

        travel_to(2.hours.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(bad_attributes) }
          dossier.save!
        end

        aggregate_failures "resetting the buffer restores the last merged values" do
          expect(draft_champ_99.value).to eq("bad")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("bad")

          dossier.reset_user_buffer_stream!

          expect(draft_champ_99.value).to eq("Hello!!!")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer is the best, for sure !")
        end
      end

      context "missing champs" do
        before { dossier.champ_data.where(type: 'Champs::TextChamp').destroy_all; dossier.champ_data.reload }

        it {
          subject
          dossier.save!

          expect(draft_champ_99.stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(draft_champ_991.stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(draft_champ_994.stream).to eq(Dossier::USER_BUFFER_STREAM)

          expect(draft_champ_99.value).to eq("Hello")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer")

          expect(dossier.history.size).to eq(0)
          dossier.merge_user_buffer_stream!
          expect(dossier.history.size).to eq(0)
        }
      end

      context "piece_justificative or titre_identite nature" do
        let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
        let(:public_type_de_champs) do
          [
            { type: :piece_justificative, libelle: "Un champ pj", stable_id: 98 },
            { type: :piece_justificative, nature: 'titre_identite', libelle: "Un champ titre identite", stable_id: 99 },
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
          expect(dossier.history.map(&:piece_justificative_file).map { [_1.record.type, _1.attached?] }).to match_array([['Champs::PieceJustificativeChamp', true], ['Champs::PieceJustificativeChamp', false]])

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
          dossier.send(:champ_data_on_stream).find { _1.stable_id == stable_id && _1.row_id == row_id }
        end
      end

      def draft_row(stable_id, row_id)
        dossier.with_update_stream(dossier.user) do
          dossier.send(:champ_data_on_stream).find { _1.stable_id == stable_id && _1.row_id == row_id }
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

      subject do
        assign_champs_attributes(user_attributes_0)
        dossier.save!
        dossier.passer_en_construction!
        dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_0) }
      end

      # Each phase happens at a distinct virtual time on purpose: champ data is
      # deduplicated by taking the most recent updated_at per public_id, and
      # `sort_by` is not stable, so rows sharing an updated_at would resolve
      # arbitrarily. Do not collapse the travel_to blocks or reuse an offset.
      it "keeps the user and instructeur buffers independent and lets a user merge win" do
        subject
        dossier.save!

        aggregate_failures "instructeur edits stay on their own buffer stream" do
          expect(dossier.instructeur_buffer_changes?).to be_truthy

          expect(main_champ_99.stream).to eq(Dossier::MAIN_STREAM)
          expect(main_champ_991.stream).to eq(Dossier::MAIN_STREAM)
          expect(main_champ_994.stream).to eq(Dossier::MAIN_STREAM)

          expect(main_champ_99.value).to eq('Bonjour')
          expect(main_champ_991.value).to eq('Au revoir')
          expect(main_champ_994.value).to be_nil

          expect(draft_champ_99.stream).to eq(Dossier::INSTRUCTEUR_BUFFER_STREAM)
          expect(draft_champ_991.stream).to eq(Dossier::INSTRUCTEUR_BUFFER_STREAM)
          expect(draft_champ_994.stream).to eq(Dossier::INSTRUCTEUR_BUFFER_STREAM)

          expect(draft_champ_99.value).to eq("Hello")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer")
          expect(dossier.history.size).to eq(0)
        end

        dossier.merge_instructeur_buffer_stream!
        dossier.champ_data.reload

        aggregate_failures "merging the instructeur buffer promotes it to main" do
          expect(main_champ_99.value).to eq("Hello")
          expect(main_champ_991.value).to eq("World")
          expect(main_champ_994.value).to eq("Greer")
          expect(dossier.history.size).to eq(2)
        end

        travel_to(10.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_1) }
          dossier.save!
        end

        aggregate_failures "new instructeur edits buffer again" do
          expect(draft_champ_99.value).to eq("Hello!!!")
          expect(draft_champ_994.value).to eq("Greer is the best, for sure !")
        end

        travel_to(20.minutes.from_now) do
          dossier.with_update_stream(dossier.user) { assign_champs_attributes(user_attributes_1) }
          dossier.save!

          aggregate_failures "the three streams hold three different values" do
            expect(main_champ_99.value).to eq("Hello")
            expect(draft_champ_99.value).to eq("Hello!!!")
            expect(user_draft_champ_99.value).to eq("Hello???")
          end

          dossier.merge_user_buffer_stream!
          dossier.touch(:en_construction_at)
          dossier.champ_data.reload
        end

        aggregate_failures "a user merge discards the conflicting instructeur edit" do
          expect(draft_champ_99.value).to eq("Hello???")
          expect(main_champ_99.value).to eq("Hello???")
          expect(main_champ_994.value).to eq("Greer")
          expect(dossier.history.size).to eq(3)
        end

        travel_to(30.minutes.from_now) do
          dossier.merge_instructeur_buffer_stream!
          dossier.champ_data.reload
        end

        aggregate_failures "the surviving instructeur edit still merges" do
          expect(main_champ_99.value).to eq("Hello???")
          expect(main_champ_994.value).to eq("Greer is the best, for sure !")
          expect(dossier.history.size).to eq(4)
        end

        travel_to(40.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(bad_attributes) }
          dossier.save!
        end

        aggregate_failures "resetting the instructeur buffer restores the merged values" do
          expect(draft_champ_99.value).to eq("bad")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("bad")

          dossier.reset_instructeur_buffer_stream!

          expect(draft_champ_99.value).to eq("Hello???")
          expect(draft_champ_991.value).to eq("World")
          expect(draft_champ_994.value).to eq("Greer is the best, for sure !")
        end

        travel_to(50.minutes.from_now) do
          dossier.with_instructeur_buffer_stream { assign_champs_attributes(attributes_2) }
          dossier.save!
          dossier.merge_instructeur_buffer_stream!
          dossier.champ_data.reload
        end

        aggregate_failures "main holds the latest values" do
          expect(main_champ_99.value).to eq("Hello...")
          expect(main_champ_991.value).to eq("World")
          expect(main_champ_994.value).to eq("Greer is the best, for sure !")
        end

        aggregate_failures "the user history stream holds the state at last submission" do
          expect(user_history_champ_99.value).to eq("Hello???")
          expect(user_history_champ_991.value).to eq("World")
          expect(user_history_champ_994.value).to eq("Greer")

          expect(user_history_champ_99.source_stream).to eq(Dossier::USER_BUFFER_STREAM)
          expect(user_history_champ_991.source_stream).to eq(Dossier::INSTRUCTEUR_BUFFER_STREAM)
          expect(user_history_champ_994.source_stream).to eq(Dossier::INSTRUCTEUR_BUFFER_STREAM)
        end
      end
    end
  end

  describe '#set_default_value_for_france_connect_champs' do
    let!(:procedure) { create(:procedure, :published, :with_api_particulier_token, public_type_de_champs:, for_individual: true) }
    let(:public_type_de_champs) { [{ type: :quotient_familial }] }
    # Memoized before any context publishes a second quotient_familial tdc.
    let(:qf_stable_id) { procedure.published_revision.type_de_champs.sole.stable_id }
    # Enumerable#find over the loaded association, not find_by: the examples
    # stub this instance, so it has to be the same object the concern reuses.
    let(:champ_qf) { dossier.champ_data.find { it.stable_id == qf_stable_id } }
    let!(:fci) { create(:france_connect_information, user: dossier.user) }

    # The champs are instantiated inside the method under test, so there is no
    # instance to stub up front; collect them as they ask to be fetched.
    let(:fetched_instances) { [] }
    let(:old_qf) { dossier.root_champs_public.find { it.stable_id == qf_stable_id } }
    let(:new_qf) { dossier.root_champs_public.find { it.stable_id != qf_stable_id } }

    def stub_fetch_later(collector)
      allow_any_instance_of(Champs::QuotientFamilialChamp)
        .to receive(:fetch_later!) do |instance|
          collector << instance
          nil
        end
    end

    def add_second_quotient_familial_tdc
      procedure.draft_revision.add_type_de_champ({
        type_champ: TypeDeChamp.type_champs.fetch(:quotient_familial),
        libelle: "QF 2",
      })
      procedure.publish_revision!(procedure.administrateurs.first)
      dossier.reload
      dossier.rebase!
    end

    context 'when dossier is in a brouillon' do
      let(:dossier) { create(:dossier, :brouillon, procedure:, for_procedure_preview: false, for_tiers: false) }

      subject { dossier.set_default_value_for_france_connect_champs(dossier.user.email) }

      context 'when the user starts a new dossier' do
        before { allow(champ_qf).to receive(:fetch_later!).and_return(nil) }

        it 'set a default value for the quotient_familial champ' do
          subject
          expect(champ_qf).to have_received(:fetch_later!)
        end
      end

      context "when the champ was attempted to be fetched, and later the user returns to their dossier" do
        before do
          champ_qf.update(external_state: 'fetched')
          dossier.reload
          allow(champ_qf).to receive(:fetch_later!).and_return(nil)
        end

        it 'does not attempt to fetch the champ again' do
          subject
          expect(champ_qf).not_to have_received(:fetch_later!)
        end
      end

      context 'when the admin add a new quotient_familial tdc' do
        before do
          champ_qf.update(external_state: 'fetched')
          add_second_quotient_familial_tdc
          stub_fetch_later(fetched_instances)
        end

        it 'does not attempt to fetch the old champ again, but does attempt to set the new champ' do
          subject

          expect(fetched_instances.map(&:stable_id)).to contain_exactly(new_qf.stable_id)
        end
      end
    end

    context 'when the dossier is in en_construction' do
      let(:dossier) { create(:dossier, :en_construction, procedure:, for_procedure_preview: false, for_tiers: false) }

      subject { dossier.with_update_stream(dossier.user).set_default_value_for_france_connect_champs(dossier.user.email) }

      context 'when the user wants to modify their dossier' do
        before do
          allow(champ_qf).to receive(:may_fetch_later!).and_return(nil)
        end

        it 'does not set a default champ on user_buffer, and does not attempt to fetch the main_stream_champ again' do
          subject
          expect(champ_qf).not_to have_received(:may_fetch_later!)
          expect(dossier.send(:champ_data_on_user_buffer_stream)).to be_empty
        end
      end

      context 'when the admin add a new quotient_familial tdc' do
        before do
          champ_qf.update(external_state: 'idle')
          add_second_quotient_familial_tdc
          stub_fetch_later(fetched_instances)
        end

        it 'does not attempt to fetch the old champ again, but does attempt to set the new champ on user_buffer_stream' do
          subject

          expect(fetched_instances.map(&:stable_id)).to contain_exactly(new_qf.stable_id)

          buffered = dossier.send(:champ_data_on_user_buffer_stream)
          expect(buffered.map(&:stable_id)).to contain_exactly(new_qf.stable_id)
        end
      end
    end
  end

  describe "#user_changed_columns" do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

    context "when the user buffer stream is empty" do
      it { expect(dossier.user_changed_columns).to eq([]) }
    end

    context "when the user buffer stream has pending changes" do
      before do
        dossier.with_update_stream(dossier.user) do
          dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            .assign_attributes(value: "Nouvelle valeur")
        end
        dossier.save!
      end

      it "returns the changed column with its new buffer value" do
        columns = dossier.user_changed_columns

        expect(columns.map(&:stable_id)).to contain_exactly(99)
        expect(columns.first.label).to eq("Un champ text")
        expect(columns.first.value).to eq("Nouvelle valeur")
      end

      it "ignores columns whose value did not change" do
        expect(dossier.user_changed_columns.map(&:stable_id)).not_to include(991)
      end
    end

    context "when the user buffer stream changes a champ inside a repetition" do
      let(:row_id) do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        dossier.project_champ(type_de_champ).row_ids.first
      end

      before do
        dossier.with_update_stream(dossier.user) do
          dossier.public_champ_for_update("994-#{row_id}", updated_by: dossier.user.email)
            .assign_attributes(value: "Valeur dans la répétition")
        end
        dossier.save!
      end

      it "returns the changed column for the repetition child" do
        columns = dossier.user_changed_columns

        column = columns.find { _1.stable_id == 994 }
        expect(column).not_to be_nil
        expect(column.value).to eq("Valeur dans la répétition")
      end
    end

    context "when the user buffer stream adds geometry to a carte (geojson) champ" do
      let(:public_type_de_champs) { [{ type: :carte, libelle: "Une carte", stable_id: 996 }] }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon) }

      before do
        dossier.with_update_stream(dossier.user) do
          champ = dossier.public_champ_for_update('996', updated_by: dossier.user.email)
          champ.update(geo_areas: [geo_area])
        end
        dossier.save!
      end

      it "returns the geojson changed column with its feature collection" do
        columns = dossier.user_changed_columns

        column = columns.find { _1.stable_id == 996 }
        expect(column).not_to be_nil
        expect(column.type).to eq(:geojson)

        feature_collection = column.value
        expect(feature_collection[:type]).to eq('FeatureCollection')
        expect(feature_collection[:features].size).to eq(1)
      end
    end

    context "when the user buffer stream attaches a file to a piece justificative (attachments) champ" do
      let(:public_type_de_champs) { [{ type: :piece_justificative, libelle: "Une pièce", stable_id: 997 }] }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      before do
        dossier.with_update_stream(dossier.user) do
          champ = dossier.public_champ_for_update('997', updated_by: dossier.user.email)
          champ.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf')
          champ.save!
        end
        dossier.save!
      end

      it "returns the attachments changed column with the attached file" do
        columns = dossier.user_changed_columns

        column = columns.find { _1.stable_id == 997 }
        expect(column).not_to be_nil
        expect(column.type).to eq(:attachments)
        expect(column.value.map { _1.filename.to_s }).to eq(['Contrat.pdf'])
      end
    end
  end

  describe "#instructeur_changed_columns" do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

    context "when the instructeur buffer stream is empty" do
      it { expect(dossier.instructeur_changed_columns).to eq([]) }
    end

    context "when the instructeur buffer stream has pending changes" do
      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('99', updated_by: 'instructeur@exemple.fr')
            .assign_attributes(value: "Correction instructeur")
        end
        dossier.save!
      end

      it "returns the changed column with its new buffer value" do
        columns = dossier.instructeur_changed_columns

        expect(columns.map(&:stable_id)).to contain_exactly(99)
        expect(columns.first.label).to eq("Un champ text")
        expect(columns.first.value).to eq("Correction instructeur")
      end

      it "does not report changes on the user buffer stream" do
        expect(dossier.user_changed_columns).to eq([])
      end
    end

    context "when the instructeur buffer stream attaches a file to a piece justificative (attachments) champ" do
      let(:public_type_de_champs) { [{ type: :piece_justificative, libelle: "Une pièce", stable_id: 997 }] }
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      before do
        dossier.with_instructeur_buffer_stream do
          champ = dossier.public_champ_for_update('997', updated_by: 'instructeur@exemple.fr')
          champ.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf')
          champ.save!
        end
        dossier.save!
      end

      it "returns the attachments changed column with the attached file" do
        columns = dossier.instructeur_changed_columns

        column = columns.find { _1.stable_id == 997 }
        expect(column).not_to be_nil
        expect(column.type).to eq(:attachments)
        expect(column.value.map { _1.filename.to_s }).to eq(['Contrat.pdf'])
      end
    end

    context "when the instructeur buffer stream changes a champ inside a repetition" do
      let(:row_id) do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        dossier.project_champ(type_de_champ).row_ids.first
      end

      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update("994-#{row_id}", updated_by: 'instructeur@exemple.fr')
            .assign_attributes(value: "Correction dans la répétition")
        end
        dossier.save!
      end

      it "returns the changed column for the repetition child" do
        column = dossier.instructeur_changed_columns.find { _1.stable_id == 994 }

        expect(column).not_to be_nil
        expect(column.value).to eq("Correction dans la répétition")
      end
    end
  end

  describe "#reload" do
    it "drops the memoized champs so a concurrent write is picked up" do
      expect(dossier.root_champs_public.size).to eq(4)

      dossier.champ_data.where(stable_id: 99).destroy_all
      # still memoized
      expect(dossier.root_champs_public.find { _1.stable_id == 99 }).to be_persisted

      dossier.reload

      expect(dossier.root_champs_public.find { _1.stable_id == 99 }).to be_new_record
    end
  end

  describe "#merge_user_buffer_stream!" do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }

    it "returns nil and archives nothing when the buffer is empty" do
      expect { expect(dossier.merge_user_buffer_stream!).to be_nil }
        .not_to change { dossier.history.size }
    end

    it "returns the history stream the previous main values were moved to" do
      dossier.with_update_stream(dossier.user) do
        dossier.public_champ_for_update('99', updated_by: dossier.user.email).assign_attributes(value: "Nouvelle valeur")
      end
      dossier.save!

      history_stream = dossier.merge_user_buffer_stream!

      expect(history_stream).to start_with(Dossier::HISTORY_STREAM)
      expect(dossier.history.map(&:stream)).to all(eq(history_stream))
      expect(dossier.champ_data.find { _1.stable_id == 99 && _1.main_stream? }.checkpoint).to eq(history_stream)
    end

    it "stamps value_updated_at on merged champs" do
      dossier.with_update_stream(dossier.user) do
        dossier.public_champ_for_update('99', updated_by: dossier.user.email).assign_attributes(value: "Nouvelle valeur")
      end
      dossier.save!

      dossier.merge_user_buffer_stream!

      merged = dossier.champ_data.find { _1.stable_id == 99 && _1.main_stream? }.reload
      expect(merged.read_attribute(:value_updated_at)).to eq(merged.updated_at)
      expect(merged.read_attribute(:value_updated_at)).to be_present
    end
  end
end
