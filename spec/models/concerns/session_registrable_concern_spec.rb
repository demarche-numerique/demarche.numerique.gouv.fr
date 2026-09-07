# frozen_string_literal: true

describe SessionRegistrableConcern do
  let(:super_admin) { create(:super_admin) }
  let(:chrome_on_mac) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36" }

  describe '#open_user_session!' do
    it 'keeps the user agent and leaves the session without a deadline for now' do
      user_session = super_admin.open_user_session!(chrome_on_mac)

      expect(user_session.user_agent).to eq(chrome_on_mac)
      expect(user_session.expires_at).to be_nil
    end
  end

  describe '#revoke_sessions!' do
    it 'revokes every usable session, with the given reason' do
      first = super_admin.open_user_session!(chrome_on_mac)
      second = super_admin.open_user_session!(chrome_on_mac)

      super_admin.revoke_sessions!(reason: :support)

      expect(first.reload.unusable_reason).to eq(:support)
      expect(second.reload.unusable_reason).to eq(:support)
    end

    it 'leaves an already revoked session with its original reason' do
      user_session = super_admin.open_user_session!(chrome_on_mac)
      user_session.update!(revoked_at: 1.day.ago, revoked_reason: 'logout_device')

      super_admin.revoke_sessions!(reason: :support)

      expect(user_session.reload.unusable_reason).to eq(:logout_device)
    end
  end

  describe '#revoke_sessions! with except:' do
    it 'spares the session it is given' do
      kept = super_admin.open_user_session!(chrome_on_mac)
      other = super_admin.open_user_session!(chrome_on_mac)

      super_admin.revoke_sessions!(reason: :new_session, except: kept)

      expect(kept.reload).not_to be_unusable
      expect(other.reload.unusable_reason).to eq(:new_session)
    end
  end
end
