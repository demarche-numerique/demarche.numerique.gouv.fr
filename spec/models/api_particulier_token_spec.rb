# frozen_string_literal: true

describe APIParticulierToken, type: :model do
  let(:api_particulier_token) { APIParticulierToken.new(token) }

  # Le jeton saisi par un administrateur qui a mis n'importe quoi : il passait
  # l'ancienne validation de format, et faisait échouer tous les appels (RAILS-MGX).
  let(:garbage_token) { "azertyuiopqsdfgh" }

  describe "#unusable?" do
    subject { api_particulier_token.unusable? }

    context "without token" do
      let(:token) { nil }

      it { is_expected.to eq(true) }
    end

    context "with a garbage token" do
      let(:token) { garbage_token }

      it { is_expected.to eq(true) }
    end

    context "with an expired token" do
      let(:token) { JWT.encode({ exp: 1.day.ago.to_i }, nil, 'none') }

      it { is_expected.to eq(true) }
    end

    context "with a token expiring soon" do
      let(:token) { JWT.encode({ exp: 3.weeks.from_now.to_i }, nil, 'none') }

      it { is_expected.to eq(false) }
    end

    context "with a token without expiration claim" do
      let(:token) { JWT.encode({ sub: 'demarche' }, nil, 'none') }

      it { is_expected.to eq(false) }
    end
  end

  describe "#needs_renewal?" do
    subject { api_particulier_token.needs_renewal? }

    context "without token" do
      let(:token) { nil }

      it { is_expected.to eq(false) }
    end

    context "with a garbage token" do
      let(:token) { garbage_token }

      it { is_expected.to eq(true) }
    end

    context "with a token expiring in 2 months" do
      let(:token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }

      it { is_expected.to eq(false) }
    end

    context "with a token expiring in 3 weeks" do
      let(:token) { JWT.encode({ exp: 3.weeks.from_now.to_i }, nil, 'none') }

      it { is_expected.to eq(true) }
    end
  end

  describe "#notification_due?" do
    subject { api_particulier_token.notification_due?(last_sent_at) }

    context "with a healthy token" do
      let(:token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }
      let(:last_sent_at) { nil }

      it { is_expected.to eq(false) }
    end

    context "with a token expiring in 3 weeks" do
      let(:token) { JWT.encode({ exp: 3.weeks.from_now.to_i }, nil, 'none') }

      context "never notified" do
        let(:last_sent_at) { nil }

        it { is_expected.to eq(true) }
      end

      context "already notified within the same window" do
        let(:last_sent_at) { 1.day.ago }

        it { is_expected.to eq(false) }
      end
    end

    # Sans cela, le mail annonçant la coupure n'arriverait qu'un délai de relance
    # après l'expiration, alors que les appels sont déjà coupés.
    context "with a token that has just expired" do
      let(:token) { JWT.encode({ exp: 1.day.ago.to_i }, nil, 'none') }

      context "last notified before the expiry" do
        let(:last_sent_at) { 2.days.ago }

        it { is_expected.to eq(true) }
      end

      context "already notified since the expiry" do
        let(:last_sent_at) { 1.hour.ago }

        it { is_expected.to eq(false) }
      end
    end

    context "with a garbage token" do
      let(:token) { garbage_token }

      context "never notified" do
        let(:last_sent_at) { nil }

        it { is_expected.to eq(true) }
      end

      context "notified recently" do
        let(:last_sent_at) { 2.days.ago }

        it { is_expected.to eq(false) }
      end

      context "notified more than a month ago" do
        let(:last_sent_at) { 2.months.ago }

        it { is_expected.to eq(true) }
      end
    end
  end
end
