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
        it { is_expected.to be_falsey }
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
end
