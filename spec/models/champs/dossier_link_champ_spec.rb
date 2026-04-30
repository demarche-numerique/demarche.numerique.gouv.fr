# frozen_string_literal: true

describe Champs::DossierLinkChamp, type: :model do
  let(:types_de_champ_public) { [{ type: :dossier_link, mandatory: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(value:) } }
  let(:value) { nil }
  let(:mandatory) { false }

  describe 'prefilling validations' do
    let(:linked_dossier) { create(:dossier, :en_construction) }
    describe 'value' do
      subject { champ.valid?(:prefill) }

      context 'when nil' do
        let(:value) { nil }

        it { expect(subject).to eq(true) }
      end

      context 'when empty' do
        let(:value) { '' }

        it { expect(subject).to eq(true) }
      end

      context 'when an integer' do
        let(:value) { linked_dossier.id }

        it { expect(subject).to eq(true) }
      end

      context 'when a string representing an integer' do
        let(:value) { linked_dossier.id.to_s }

        it { expect(subject).to eq(true) }
      end

      context 'when it can be casted as integer' do
        let(:value) { 'totoro' }

        it { expect(subject).to eq(false) }
      end
    end
  end

  describe 'validation' do
    subject { champ.validate(:champs_public_value) }

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
    subject { champ.validate(:champs_public_value) }

    let(:mandatory) { false }
    let(:user) { dossier.user }
    let(:allowed_procedure) { create(:procedure) }
    let(:other_procedure) { create(:procedure) }
    let(:type_de_champ) { procedure.draft_revision.types_de_champ.first }

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
end
