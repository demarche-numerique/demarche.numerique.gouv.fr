# frozen_string_literal: true

describe FranceConnectInformation, type: :model do
  describe 'validation' do
    context 'france_connect_particulier_id' do
      it do
        is_expected.not_to allow_value(nil).for(:france_connect_particulier_id)
        is_expected.not_to allow_value('').for(:france_connect_particulier_id)
        is_expected.to allow_value('mon super projet').for(:france_connect_particulier_id)
      end
    end
  end

  describe 'safely_associate_user!' do
    let(:email) { 'A@email.com' }
    let(:fci) { build(:france_connect_information) }

    subject { fci.safely_associate_user!(email) }

    context 'when there is no user with the same email' do
      it 'creates a new user' do
        expect { subject }.to change(User, :count).by(1)
      end

      it 'sets the correct attributes on the user' do
        subject
        user = User.find_by(email: email.downcase)
        expect(user).not_to be_nil
        expect(user.confirmed_at).to be_present
      end

      it 'associates the user with the FranceConnectInformation' do
        subject
        expect(fci.reload.user.email).to eq(email.downcase)
      end

      it 'links the invites sent to this email' do
        invite = create(:invite, email: email.downcase, user: nil, dossier: dossiers.en_construction)

        subject

        expect(invite.reload.user).to eq(fci.reload.user)
      end
    end

    context 'when a user with the same email already exists due to race condition' do
      let!(:existing_user) { create(:user, email: email.downcase) }
      let!(:fci) { create(:france_connect_information) } # Assurez-vous que fci est créé et sauvegardé

      before do
        call_count = 0
        allow(User).to receive(:create!).and_wrap_original do
          call_count += 1
          if call_count == 1
            raise ActiveRecord::RecordNotUnique
          else
            existing_user
          end
        end
        allow(fci).to receive(:send_custom_confirmation_instructions)
      end

      it 'is noop' do
        expect(fci.safely_associate_user!(email)).to eq(true)
      end

      it 'does not create a new user' do
        expect {
          fci.safely_associate_user!(email)
        }.to_not change(User, :count)
      end

      it 'does not associate with any user' do
        expect(fci.user).to be_nil
        fci.safely_associate_user!(email)
        expect(fci.reload.user).to be_nil
      end
    end
  end

  describe '#valid_for_merge?' do
    let(:fci) { create(:france_connect_information) }

    subject { fci.valid_for_merge? }

    context 'when the merge token is young enough' do
      before { fci.merge_token_created_at = 1.minute.ago }

      it { is_expected.to be(true) }

      context 'but the fci is already linked to an user' do
        before { fci.update(user: create(:user)) }

        it { is_expected.to be(false) }
      end
    end

    context 'when the merge token is too old' do
      before { fci.merge_token_created_at = (FranceConnectInformation::MERGE_VALIDITY + 1.minute).ago }

      it { is_expected.to be(false) }
    end
  end

  describe '#create_merge_token!' do
    let(:fci) { create(:france_connect_information) }

    it 'returns a merge_token and register it s creation date' do
      token = fci.create_merge_token!(login_method: :france_connect_plus)

      expect(fci.merge_token).to eq(token)
      expect(fci.merge_token_created_at).not_to be_nil
      expect(fci.merge_login_method).to eq('france_connect_plus')
    end

    it 'voids the email link of the previous merge' do
      fci.update!(requested_email: 'other@example.org')
      fci.create_email_merge_token!

      fci.create_merge_token!(login_method: :france_connect_plus)

      expect(fci.reload).to have_attributes(email_merge_token: nil, email_merge_token_created_at: nil, requested_email: nil)
    end
  end

  describe '#safely_update_user' do
    it 'forgets how the merge started' do
      fci = create(:france_connect_information)
      fci.create_merge_token!(login_method: :france_connect_plus)

      fci.safely_update_user(user: create(:user))

      expect(fci.reload.merge_login_method).to be_nil
    end
  end
end
