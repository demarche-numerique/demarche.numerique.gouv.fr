# frozen_string_literal: true

describe DossierPolicy do
  subject(:policy) { described_class.new(user, dossier) }

  let(:owner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:procedure) { create(:procedure, :published) }
  let(:dossier) { create(:dossier, state, user: owner, procedure: procedure) }
  let(:state) { :en_construction }

  describe '#initialize' do
    let(:state) { :brouillon }

    context 'when user is nil' do
      let(:user) { nil }

      it 'raises Pundit::NotAuthorizedError' do
        expect { policy }.to raise_error(Pundit::NotAuthorizedError, /must be logged in/)
      end
    end

    context 'when user is present' do
      let(:user) { owner }

      it 'exposes the user and record' do
        expect(policy.user).to eq(owner)
        expect(policy.record).to eq(dossier)
      end

      it 'exposes the instructeur when the user has one' do
        instructeur = create(:instructeur, user: owner)
        expect(policy.instructeur).to eq(instructeur)
      end

      it 'has a nil instructeur when the user is not an instructeur' do
        expect(policy.instructeur).to be_nil
      end
    end
  end

  describe '#read?' do
    subject { policy.read? }

    shared_examples 'owner and invited access' do
      context 'when the user owns the dossier' do
        let(:user) { owner }
        it { is_expected.to be_truthy }
      end

      context 'when the user is invited to the dossier' do
        let(:user) { create(:user) }
        before { create(:invite, dossier: dossier, user: user) }
        it { is_expected.to be_truthy }
      end

      context 'when the user has no relation to the dossier' do
        let(:user) { stranger }
        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is brouillon' do
      let(:state) { :brouillon }

      include_examples 'owner and invited access'

      context 'when the user is an instructeur assigned to the groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it 'denies read access on a brouillon (instructeurs do not see brouillons)' do
          is_expected.to be_falsey
        end
      end
    end

    context 'when the dossier is en_construction' do
      let(:state) { :en_construction }

      include_examples 'owner and invited access'

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end

      context 'when the user is an instructeur assigned to another procedure' do
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

      context 'when the user is both owner and instructeur' do
        let(:instructeur) { create(:instructeur, user: owner) }
        let(:user) { owner }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when the dossier is en_instruction' do
      let(:state) { :en_instruction }

      include_examples 'owner and invited access'

      context 'when the user is an instructeur assigned to the dossier groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end

      context 'when the user is an instructeur of another groupe' do
        let(:other_groupe) { create(:groupe_instructeur, procedure: procedure) }
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { other_groupe.instructeurs << instructeur }

        it { is_expected.to be_falsey }
      end
    end

    context 'when the dossier is accepte' do
      let(:state) { :accepte }

      include_examples 'owner and invited access'

      context 'when the user is an instructeur assigned to the groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when the dossier is refuse' do
      let(:state) { :refuse }

      include_examples 'owner and invited access'

      context 'when the user is an instructeur assigned to the groupe' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before { instructeur.assign_to_procedure(procedure) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when the procedure requires FranceConnect+' do
      let(:procedure) { create(:procedure, :published, france_connect_plus_required: true) }

      before { allow(FranceConnectPlusService).to receive(:enabled?).and_return(true) }

      context 'when the owner signed in another way' do
        let(:user) { owner }
        before { Current.user_session = UserSession.new(login_method: :password) }

        it { is_expected.to be_falsey }
      end

      context 'when an invite signed in another way' do
        let(:user) { create(:user) }
        before do
          create(:invite, dossier:, user:)
          Current.user_session = UserSession.new(login_method: :france_connect)
        end

        it { is_expected.to be_falsey }
      end

      context 'when the owner signed in with FranceConnect+' do
        let(:user) { owner }
        before { Current.user_session = UserSession.new(login_method: :france_connect_plus) }

        it { is_expected.to be_truthy }
      end

      context 'when an instructeur of the groupe reads it' do
        let(:instructeur) { create(:instructeur) }
        let(:user) { instructeur.user }
        before do
          instructeur.assign_to_procedure(procedure)
          Current.user_session = UserSession.new(login_method: :password)
        end

        it { is_expected.to be_truthy }
      end
    end
  end
end
