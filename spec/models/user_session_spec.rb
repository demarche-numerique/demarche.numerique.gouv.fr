# frozen_string_literal: true

describe UserSession, type: :model do
  let(:sessionable) { users.usager }

  describe 'schema' do
    it 'carries a deadline, a revocation and a device label' do
      is_expected.to have_db_column(:expires_at).of_type(:datetime)
      is_expected.to have_db_column(:revoked_at).of_type(:datetime)
      is_expected.to have_db_column(:revoked_reason).of_type(:string)
      is_expected.to have_db_column(:user_agent).of_type(:string)
    end

    it 'indexes lookups by owner and revocation' do
      is_expected.to have_db_index([:sessionable_type, :sessionable_id, :revoked_at])
    end
  end

  describe '#unusable?' do
    it 'is false while the row is neither revoked nor past its deadline' do
      user_session = UserSession.create!(sessionable:, expires_at: 1.hour.from_now)

      expect(user_session).not_to be_unusable
    end

    it 'is true once revoked, and gives back the revocation reason' do
      user_session = UserSession.create!(sessionable:, revoked_at: Time.current, revoked_reason: 'logout_device')

      expect(user_session).to be_unusable
      expect(user_session.unusable_reason).to eq(:logout_device)
    end

    it 'is true once the deadline passed, with reason :expired' do
      user_session = UserSession.create!(sessionable:, expires_at: 1.second.ago)

      expect(user_session).to be_unusable
      expect(user_session.unusable_reason).to eq(:expired)
    end

    it 'never expires a row without a deadline' do
      user_session = UserSession.create!(sessionable:, expires_at: nil, created_at: 10.years.ago)

      expect(user_session).not_to be_unusable
    end
  end

  describe '.usable' do
    it 'keeps only the rows that are neither revoked nor past their deadline' do
      alive = UserSession.create!(sessionable:, expires_at: 1.hour.from_now)
      endless = UserSession.create!(sessionable:, expires_at: nil)
      revoked = UserSession.create!(sessionable:, revoked_at: Time.current, revoked_reason: 'logout_all')
      expired = UserSession.create!(sessionable:, expires_at: 1.second.ago)

      usable = UserSession.where(sessionable:).usable

      expect(usable).to contain_exactly(alive, endless)
      expect(usable).not_to include(revoked, expired)
    end
  end
end
