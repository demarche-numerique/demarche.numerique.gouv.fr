# frozen_string_literal: true

describe Champs::DossierLinkChamp, type: :model do
  let(:public_type_de_champs) { [{ type: :dossier_link, mandatory: }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
  let(:value) { nil }
  let(:mandatory) { false }

  describe 'validation' do
    subject { champ.validate(:champ_value) }

    context 'when not mandatory' do
      let(:mandatory) { false }
      let(:value) { nil }
      it { is_expected.to be_truthy }
    end

    context 'when mandatory' do
      let(:mandatory) { true }
      context 'when valid id' do
        let(:value) { create(:dossier, :en_construction).id }
        it { is_expected.to be_truthy }
      end

      context 'when invalid id' do
        let(:value) { 'kthxbye' }

        it 'is invalid with only the format error' do
          is_expected.to be_falsey
          expect(champ.errors).to be_of_kind(:value, :invalid)
          expect(champ.errors).not_to be_of_kind(:value, :not_found)
        end
      end

      context 'when a valid id is followed by other characters' do
        let(:value) { "#{create(:dossier, :en_construction).id} abc" }

        it 'is invalid with a format error' do
          is_expected.to be_falsey
          expect(champ.errors).to be_of_kind(:value, :invalid)
        end
      end

      context 'when id of a deleted dossier' do
        let(:value) { create(:deleted_dossier).dossier_id }

        it { is_expected.to be_truthy }
      end

      context 'when id of a brouillon dossier' do
        let(:value) { create(:dossier).id }

        it 'is invalid with brouillon_not_allowed error' do
          is_expected.to be_falsey
          expect(champ.errors.added?(:value, :brouillon_not_allowed)).to be(true)
        end
      end
    end
  end

  describe 'dossier_in_allowed_procedures validation' do
    subject { champ.validate(:champ_value) }

    let(:mandatory) { false }
    let(:user) { dossier.user }
    let(:allowed_procedure) { create(:procedure) }
    let(:other_procedure) { create(:procedure) }
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }

    before do
      type_de_champ.update!(options: type_de_champ.options.merge(
        'procedures_limit' => '1',
        'dossier_link_procedure_ids' => [allowed_procedure.id]
      ))
    end

    context 'when dossier belongs to an allowed procedure and to the current user' do
      let(:value) { create(:dossier, :en_construction, procedure: allowed_procedure, user:).id }
      it { is_expected.to be_truthy }
    end

    context 'when dossier is expired (auto-deleted) but belongs to an allowed procedure and to the current user' do
      let(:value) { create(:dossier, :en_construction, :hidden_by_expired, procedure: allowed_procedure, user:).id }
      it { is_expected.to be_truthy }
    end

    context 'when dossier does not belong to an allowed procedure' do
      let(:value) { create(:dossier, :en_construction, procedure: other_procedure, user:).id }

      it 'is invalid with correct error message' do
        is_expected.to be_falsey
        expect(champ.errors.full_messages).to include("Ce dossier n’est pas dans une démarche autorisée")
      end
    end

    context 'when dossier belongs to another user' do
      let(:value) { create(:dossier, :en_construction, procedure: allowed_procedure).id }

      it 'is invalid' do
        is_expected.to be_falsey
      end
    end

    context 'when deleted dossier belongs to an allowed procedure and to the current user' do
      let(:value) { create(:deleted_dossier, procedure: allowed_procedure, user_id: user.id).dossier_id }
      it { is_expected.to be_truthy }
    end

    context 'when deleted dossier does not belong to an allowed procedure' do
      let(:value) { create(:deleted_dossier, procedure: other_procedure, user_id: user.id).dossier_id }

      it 'is invalid with correct error message' do
        is_expected.to be_falsey
        expect(champ.errors.full_messages).to include("Ce dossier n’est pas dans une démarche autorisée")
      end
    end

    context 'when deleted dossier belongs to another user' do
      let(:value) { create(:deleted_dossier, procedure: allowed_procedure).dossier_id }

      it 'is invalid' do
        is_expected.to be_falsey
      end
    end

    context 'when procedures_limit is not enabled' do
      before do
        type_de_champ.update!(options: type_de_champ.options.merge('procedures_limit' => nil))
      end

      let(:value) { create(:dossier, :en_construction, procedure: other_procedure, user:).id }
      it { is_expected.to be_truthy }
    end

    context 'when no allowed procedures configured' do
      before do
        type_de_champ.update!(options: type_de_champ.options.merge('dossier_link_procedure_ids' => []))
      end

      let(:value) { create(:dossier, :en_construction, procedure: other_procedure, user:).id }
      it { is_expected.to be_truthy }
    end
  end

  describe '#selectable?' do
    let(:allowed_procedure) { create(:procedure) }
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }

    subject { champ.selectable? }

    context 'when the field is not limited to procedures' do
      it { is_expected.to be(false) }
    end

    context 'when the field is limited' do
      before do
        type_de_champ.update!(options: type_de_champ.options.merge(
          'procedures_limit' => '1',
          'dossier_link_procedure_ids' => [allowed_procedure.id]
        ))
      end

      context 'and the user has a submitted dossier on an allowed procedure' do
        before { create(:dossier, :en_construction, procedure: allowed_procedure, user: dossier.user) }

        it { is_expected.to be(true) }
      end

      context 'and the user has no dossier to propose' do
        it { is_expected.to be(false) }
      end

      context 'and the user only has an expired (auto-deleted) dossier' do
        before { create(:dossier, :en_construction, :hidden_by_expired, procedure: allowed_procedure, user: dossier.user) }

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#linkable_dossiers_by_procedure' do
    let(:allowed_procedure) { create(:procedure) }
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:user) { dossier.user }

    before do
      type_de_champ.update!(options: type_de_champ.options.merge(
        'procedures_limit' => '1',
        'dossier_link_procedure_ids' => [allowed_procedure.id]
      ))
    end

    subject { champ.linkable_dossiers_by_procedure.values.flatten.map(&:id) }

    context 'with an expired (soft-deleted, still present) deposited dossier' do
      let!(:expired_dossier) { create(:dossier, :en_construction, :hidden_by_expired, procedure: allowed_procedure, user:) }

      it { is_expected.to include(expired_dossier.id) }
    end

    context 'with a dossier the user deleted himself' do
      let!(:hidden_dossier) { create(:dossier, :en_construction, :hidden_by_user, procedure: allowed_procedure, user:) }

      it { is_expected.not_to include(hidden_dossier.id) }
    end

    context 'with an en_instruction dossier the user deleted himself' do
      let!(:hidden_dossier) { create(:dossier, :en_instruction, :hidden_by_user, procedure: allowed_procedure, user:) }

      it { is_expected.not_to include(hidden_dossier.id) }
    end

    context 'with a deposited dossier purged for expiration (DeletedDossier reason: expired)' do
      let!(:deleted) do
        create(:deleted_dossier, reason: :expired, user_id: user.id, procedure: allowed_procedure,
                                 dossier_id: 99_999, depose_at: 3.days.ago.to_date)
      end

      it { is_expected.to include(deleted.dossier_id) }
    end

    context 'with a purged dossier deleted for another reason (DeletedDossier reason: user_request)' do
      let!(:deleted) do
        create(:deleted_dossier, reason: :user_request, user_id: user.id, procedure: allowed_procedure,
                                 dossier_id: 99_998, depose_at: 3.days.ago.to_date)
      end

      it { is_expected.not_to include(deleted.dossier_id) }
    end
  end

  describe 'linked procedure id and submission date' do
    let(:submitted_at) { Time.zone.local(2026, 3, 4, 0, 30) }

    def submitted(dossier) = dossier.tap { it.update_columns(depose_at: submitted_at) }

    it 'stores the procedure and the submission date of a live dossier' do
      linked = submitted(dossiers.en_construction)
      champ.update(value: linked.id)
      expect(champ.reload.value_json).to eq('procedure_id' => linked.procedure.id, 'submitted_on' => '2026-03-04')
    end

    it 'stores the submission date in Paris time for a dossier submitted just after midnight' do
      linked = dossiers.en_construction.tap { it.update_columns(depose_at: ActiveSupport::TimeZone['Europe/Paris'].local(2025, 3, 1, 0, 30)) }
      expect(linked.reload.depose_at.utc.to_date).to eq(Date.new(2025, 2, 28))
      champ.update(value: linked.id)
      expect(champ.reload.value_json).to eq('procedure_id' => linked.procedure.id, 'submitted_on' => '2025-03-01')
    end

    it 'stores the procedure and the submission date of a purged dossier' do
      deleted = create(:deleted_dossier, dossier_id: 987_654, depose_at: Date.new(2026, 3, 4))
      champ.update(value: '987654')
      expect(champ.reload.value_json).to eq('procedure_id' => deleted.procedure_id, 'submitted_on' => '2026-03-04')
    end

    it 'stores no submission date for a dossier never submitted' do
      linked = create(:dossier, :brouillon)
      deleted = create(:deleted_dossier, dossier_id: 987_654, depose_at: nil)
      champ.update(value: linked.id)
      expect(champ.reload.value_json).to eq('procedure_id' => linked.procedure.id)
      champ.update(value: '987654')
      expect(champ.reload.value_json).to eq('procedure_id' => deleted.procedure_id)
    end

    it 'follows the value' do
      first = submitted(create(:dossier, :en_construction))
      second = create(:dossier, :en_construction).tap { it.update_columns(depose_at: Time.zone.local(2026, 5, 6, 12)) }
      champ.update(value: first.id)
      champ.update(value: second.id)
      expect(champ.reload.value_json).to eq('procedure_id' => second.procedure.id, 'submitted_on' => '2026-05-06')
      champ.update(value: nil)
      expect(champ.reload.value_json).to be_nil
    end

    ['abc', '99999999999999999999', '424242424'].each do |value|
      it "stores nothing for #{value}" do
        expect { champ.update(value:) }.not_to raise_error
        expect(champ.reload.value_json).to be_nil
      end
    end

    it 'keeps the procedure and the submission date when the user buffer is merged' do
      linked = submitted(dossiers.en_construction)
      public_id = champ.public_id
      dossier.with_update_stream(dossier.user) do
        buffer_champ = dossier.public_champ_for_update(public_id, updated_by: dossier.user.email)
        buffer_champ.update!(value: linked.id)
        expect(buffer_champ.stream).to eq(Dossier::USER_BUFFER_STREAM)
      end
      dossier.merge_user_buffer_stream!
      main_champ = dossier.reload.root_champs_public.first
      expect(main_champ.stream).to eq(Dossier::MAIN_STREAM)
      expect(main_champ.value_json).to eq('procedure_id' => linked.procedure.id, 'submitted_on' => '2026-03-04')
    end
  end

  describe 'linked dossier metadata at submission' do
    let(:user) { create(:user) }
    let(:dossier) { create(:dossier, :brouillon, procedure:, user:) }
    let(:linked) { create(:dossier, :brouillon, user:) }

    def link!(target)
      dossier.with_update_stream(user) do
        dossier.public_champ_for_update(dossier.root_champs_public.first.public_id, updated_by: user.email).update!(value: target.id.to_s)
      end
    end

    def main_champ = Dossier.find(dossier.id).champ_data.find { it.stable_id == dossier.root_champs_public.first.stable_id && it.stream == Dossier::MAIN_STREAM }

    def submit(target)
      Dossier.find(target.id).tap { it.with_champs.passer_en_construction! }
    end

    def deposit(target) = target.tap { it.update_columns(depose_at: Time.zone.local(2026, 3, 4, 10)) }.depose_at.to_date

    def completed(submitted_on) = { 'procedure_id' => linked.procedure.id, 'submitted_on' => submitted_on.iso8601 }

    it 'completes the submission date of a link stored while the target was a brouillon' do
      link!(linked)
      expect(main_champ.value_json).to eq('procedure_id' => linked.procedure.id)
      stamps = main_champ.slice(:updated_at, :value_updated_at)

      submitted_on = submit(linked).depose_at.to_date
      submit(dossier)

      expect(main_champ.value_json).to eq(completed(submitted_on))
      expect(main_champ.slice(:updated_at, :value_updated_at)).to eq(stamps)
    end

    it 'leaves a link to a target still in brouillon without a date' do
      link!(linked)

      expect { submit(dossier) }.not_to raise_error
      expect(main_champ.value_json).to eq('procedure_id' => linked.procedure.id)
    end

    it 'completes the submission date when the dossier is submitted again after a correction' do
      link!(linked)
      submit(dossier)
      submitted_on = deposit(linked)

      Dossier.find(dossier.id).tap { it.with_champs.usager_submit_en_construction! }

      expect(main_champ.value_json).to eq(completed(submitted_on))
    end

    it 'keeps a complete link without querying the linked dossier' do
      submitted_on = deposit(linked)
      link!(linked)

      expect(count_queries(matching: /"deleted_dossiers"|UPDATE "champs"/) { submit(dossier) }).to eq(0)
      expect(main_champ.value_json).to eq(completed(submitted_on))
    end

    it 'leaves alone a champ linked to another dossier between the read and the write' do
      link!(linked)
      deposit(linked)
      other = create(:dossier, :en_construction)
      other_value_json = { 'procedure_id' => other.procedure.id, 'submitted_on' => other.depose_at.to_date.iso8601 }
      champ = main_champ
      allow(described_class).to receive(:linked_value_jsons).and_wrap_original do |original, *args|
        original.call(*args).tap { ChampData.find(champ.id).update_columns(value: other.id.to_s, value_json: other_value_json) }
      end

      described_class.complete_linked_dossiers!([champ])

      expect(main_champ.value_json).to eq(other_value_json)
      expect(champ.value_json).to eq('procedure_id' => linked.procedure.id)
    end
  end
end
