# frozen_string_literal: true

describe ChampPolicy do
  subject(:policy) { described_class.new(user, champ) }

  let(:owner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:procedure) do
    create(:procedure, :published,
      types_de_champ_public: [{ type: :text }],
      types_de_champ_private: [{ type: :text }])
  end
  let(:dossier) do
    create(:dossier, state,
      user: owner,
      procedure: procedure,
      populate_champs: true,
      populate_annotations: true)
  end
  let(:state) { :en_construction }
  let(:champ) { ChampData.find(dossier.champ_data.find { |c| !c.private? }.id) }
  let(:annotation) { ChampData.find(dossier.champ_data.find(&:private?).id) }

  describe '#initialize' do
    let(:state) { :brouillon }

    context 'when user is nil' do
      let(:user) { nil }

      it 'raises Pundit::NotAuthorizedError' do
        expect { policy }.to raise_error(Pundit::NotAuthorizedError, /must be logged in/)
      end
    end
  end

  describe '#update?' do
    subject { policy.update? }

    context 'when the dossier is brouillon' do
      let(:state) { :brouillon }

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_truthy }
      end

      context 'when the user is invited to the dossier' do
        let(:user) { create(:user) }
        before { create(:invite, dossier: dossier, user: user) }
        it { is_expected.to be_truthy }
      end

      context 'when the user is a stranger' do
        let(:user) { stranger }
        it { is_expected.to be_falsey }
      end

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it 'cannot update a brouillon champ (only the owner/invited can)' do
          is_expected.to be_falsey
        end
      end
    end

    context 'when the dossier is en_construction' do
      let(:state) { :en_construction }

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_truthy }
      end

      context 'when the user is invited to the dossier' do
        let(:user) { create(:user) }
        before { create(:invite, dossier: dossier, user: user) }
        it { is_expected.to be_truthy }
      end

      context 'when the user is a stranger' do
        let(:user) { stranger }
        it { is_expected.to be_falsey }
      end

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end

      context 'when the user is an instructeur of another procedure' do
        let(:other_procedure) { create(:procedure, :published) }
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(other_procedure) }

        it { is_expected.to be_falsey }
      end

      context 'when the user is an instructeur of another groupe on the same procedure' do
        let(:other_groupe) { create(:groupe_instructeur, procedure: procedure) }
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { other_groupe.instructeurs << instructeur }

        it { is_expected.to be_falsey }
      end

      context 'when the dossier has no groupe_instructeur' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before do
          instructeur.assign_to_procedure(procedure)
          dossier.update_column(:groupe_instructeur_id, nil)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is en_instruction' do
      let(:state) { :en_instruction }

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_falsey }
      end

      context 'when the user is invited to the dossier' do
        let(:user) { create(:user) }
        before { create(:invite, dossier: dossier, user: user) }
        it { is_expected.to be_falsey }
      end

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it 'denies update — champs are frozen once the dossier is en_instruction' do
          is_expected.to be_falsey
        end
      end
    end

    context 'when the dossier is accepte' do
      let(:state) { :accepte }

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_falsey }
      end

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#update_annotation?' do
    subject { policy.update_annotation? }

    let(:champ) { annotation }

    context 'when the dossier is brouillon' do
      let(:state) { :brouillon }

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it 'denies annotation updates on a brouillon' do
          is_expected.to be_falsey
        end
      end

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is en_construction' do
      let(:state) { :en_construction }

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end

      context 'when the user is an instructeur of another groupe on the same procedure' do
        let(:other_groupe) { create(:groupe_instructeur, procedure: procedure) }
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { other_groupe.instructeurs << instructeur }

        it { is_expected.to be_falsey }
      end

      context 'when the user is the owner (not an instructeur)' do
        let(:user) { owner }
        it { is_expected.to be_falsey }
      end

      context 'when the user is invited (not an instructeur)' do
        let(:user) { create(:user) }
        before { create(:invite, dossier: dossier, user: user) }
        it { is_expected.to be_falsey }
      end

      context 'when the user is a stranger' do
        let(:user) { stranger }
        it { is_expected.to be_falsey }
      end

      context 'when the dossier has no groupe_instructeur' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before do
          instructeur.assign_to_procedure(procedure)
          dossier.update_column(:groupe_instructeur_id, nil)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is en_instruction' do
      let(:state) { :en_instruction }

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it 'still allows annotations to be updated' do
          is_expected.to be_truthy
        end
      end

      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is accepte' do
      let(:state) { :accepte }

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end
    end
  end
end
