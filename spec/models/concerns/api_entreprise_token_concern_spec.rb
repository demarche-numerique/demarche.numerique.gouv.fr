# frozen_string_literal: true

describe APIEntrepriseTokenConcern do
  describe 'clearing a recorded rejection' do
    let(:procedure) { create(:procedure).tap { _1.update_column(:api_entreprise_token_rejected_at, 1.hour.ago) } }

    it 'forgets the rejection when a new token is saved' do
      expect { procedure.update!(api_entreprise_token: JWT.encode({ exp: 6.months.from_now.to_i }, nil, 'none')) }
        .to change { procedure.api_entreprise_token_rejected_at }.to(nil)
    end

    it 'forgets the rejection when the token is removed' do
      expect { procedure.update!(api_entreprise_token: nil) }
        .to change { procedure.api_entreprise_token_rejected_at }.to(nil)
    end

    it 'keeps it when something else changes' do
      expect { procedure.update!(libelle: 'un autre libellé') }
        .not_to change { procedure.api_entreprise_token_rejected_at }
    end
  end

  describe '#reject_api_entreprise_token!' do
    let(:procedure) { create(:procedure, api_entreprise_token: token) }

    before { allow(Sentry).to receive(:capture_message) }

    context 'when the procedure has its own token' do
      let(:token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }

      it 'records it so the cron stops and the administrateur is warned' do
        expect { procedure.reject_api_entreprise_token! }
          .to change { procedure.reload.api_entreprise_token_rejected_at }.from(nil)

        expect(procedure).to be_api_entreprise_token_recently_rejected
      end

      it 'holds for a while, then lets the cron try again' do
        procedure.update_column(:api_entreprise_token_rejected_at, 2.days.ago)

        expect(procedure).not_to be_api_entreprise_token_recently_rejected
      end
    end

    context 'when the procedure falls back on the instance token' do
      let(:token) { nil }

      it 'alerts operations without blocking a procedure nobody can unblock' do
        expect(Sentry).to receive(:capture_message).with(/Global API Entreprise token rejected/, any_args)

        expect { procedure.reject_api_entreprise_token! }
          .not_to change { procedure.reload.api_entreprise_token_rejected_at }

        expect(procedure).not_to be_api_entreprise_token_recently_rejected
      end
    end
  end

  context 'api_entreprise_token validity' do
    let(:valid_token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
    let(:invalid_token) { 'plouf' }
    let(:procedure) { build(:procedure, api_entreprise_token:) }

    context 'with a valid token' do
      let(:api_entreprise_token) { valid_token }

      it { expect(procedure.valid?).to eq(true) }
    end

    context 'with an invalid token' do
      let(:api_entreprise_token) { invalid_token }

      it { expect(procedure.valid?).to eq(false) }
    end

    context 'with a nil token' do
      let(:api_entreprise_token) { nil }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('API_ENTREPRISE_KEY').and_return(nil)
      end

      it { expect(procedure.valid?).to eq(true) }
    end
  end
end
