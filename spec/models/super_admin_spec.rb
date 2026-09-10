# frozen_string_literal: true

describe SuperAdmin, type: :model do
  describe '#invite_admin' do
    let(:super_admin) { create :super_admin }
    let(:valid_email) { 'paul@tps.fr' }

    subject { super_admin.invite_admin(valid_email) }

    it "has no errors" do
      user = subject
      expect(user.errors).to be_empty
      expect(user).to be_persisted

      expect(super_admin.invite_admin(nil).errors).not_to be_empty
      expect(super_admin.invite_admin('toto').errors).not_to be_empty
    end

    it 'creates a corresponding user account for the email' do
      subject
      user = User.find_by(email: valid_email)
      expect(user).to be_present
    end

    it 'creates a corresponding instructeur account for the email' do
      subject
      instructeur = Instructeur.by_email(valid_email)
      expect(instructeur).to be_present
    end

    context 'when there already is a user account with the same email' do
      before { create(:user, email: valid_email) }
      it 'still creates an admin account' do
        expect(subject.errors).to be_empty
        expect(subject).to be_persisted
      end
    end
  end

  describe 'enable_otp!' do
    let(:super_admin) { create(:super_admin, otp_required_for_login: false) }
    let(:subject) { super_admin.enable_otp! }

    it 'updates otp_required_for_login' do
      expect { subject }.to change { super_admin.otp_required_for_login? }.from(false).to(true)
    end

    it 'updates otp_secret' do
      expect { subject }.to change { super_admin.otp_secret }
    end

    it 'forgets the timestep consumed with the previous secret' do
      super_admin.update!(consumed_timestep: 1)

      expect { subject }.to change { super_admin.consumed_timestep }.to(nil)
    end
  end

  describe 'disable_otp!' do
    let(:super_admin) { create(:super_admin, otp_required_for_login: true) }
    let(:subject) { super_admin.disable_otp! }

    it 'updates otp_required_for_login' do
      expect { subject }.to change { super_admin.otp_required_for_login? }.from(true).to(false)
    end

    it 'nullifies otp_secret' do
      super_admin.enable_otp!
      expect(super_admin.reload.otp_secret).not_to be_nil

      super_admin.disable_otp!
      expect(super_admin.reload.otp_secret).to be_nil
    end
  end

  describe '#password_complexity' do
    # This password list is sorted by password complexity, according to zxcvbn (used for complexity evaluation)
    # 0 - too guessable: risky password. (guesses < 10^3)
    # 1 - very guessable: protection from throttled online attacks. (guesses < 10^6)
    # 2 - somewhat guessable: protection from unthrottled online attacks. (guesses < 10^8)
    # 3 - safely unguessable: moderate protection from offline slow-hash scenario. (guesses < 10^10)
    # 4 - very unguessable: strong protection from offline slow-hash scenario. (guesses >= 10^10)
    passwords = ['000000000000', '123456789123', 'megapass2024', 'lesdémarches', '{My-$3cure-p4ssWord}']
    min_complexity = PASSWORD_COMPLEXITY_FOR_ADMIN

    let(:email) { 'mail@beta.gouv.fr' }
    let(:super_admin) { build(:super_admin, email: email, password: password) }

    subject do
      super_admin.valid?
      super_admin.errors.full_messages
    end

    context 'when the password is too short' do
      let(:password) { 's' * (PASSWORD_MIN_LENGTH - 1) }

      it 'reports an error about password length (but not about complexity)' do
        expect(subject).to eq(["Le champ « Mot de passe » est trop court. Saisir un mot de passe avec au moins 12 caractères"])
      end
    end

    passwords[0..(min_complexity - 1)].each do |simple_password|
      context 'when the password is long enough, but too simple' do
        let(:password) { simple_password }

        it { expect(subject).to eq(["Le champ « Mot de passe » n’est pas assez complexe. Saisir un mot de passe plus complexe"]) }
      end
    end

    context 'when the password is long and complex' do
      let(:password) { passwords[min_complexity] }

      it { expect(subject).to be_empty }
    end
  end
end
