# frozen_string_literal: true

describe APIEntrepriseToken, type: :model do
  let(:api_entreprise_token) { APIEntrepriseToken.new(token) }

  describe "#can_fetch_bilans_bdf?" do
    subject { api_entreprise_token.can_fetch_bilans_bdf? }

    context "with an old token" do
      let(:token) { "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiI1MmE1YmZjMi1jMzUwLTQ4ZjQtYjY5Ni05ZWE3NmRiM2VmMjkiLCJqdGkiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJzY29wZXMiOlsiY2VydGlmaWNhdF9yZ2VfYWRlbWUiLCJtc2FfY290aXNhdGlvbnMiLCJlbnRyZXByaXNlcyIsImV4dHJhaXRzX3JjcyIsImNlcnRpZmljYXRfb3BxaWJpIiwiYXNzb2NpYXRpb25zIiwiZXRhYmxpc3NlbWVudHMiLCJmbnRwX2NhcnRlX3BybyIsInF1YWxpYmF0IiwiZW50cmVwcmlzZXNfYXJ0aXNhbmFsZXMiLCJjZXJ0aWZpY2F0X2NuZXRwIiwiZW9yaV9kb3VhbmVzIiwicHJvYnRwIiwiYWN0ZXNfaW5waSIsImV4dHJhaXRfY291cnRfaW5waSIsImF0dGVzdGF0aW9uc19zb2NpYWxlcyIsImxpYXNzZV9maXNjYWxlIiwiYXR0ZXN0YXRpb25zX2Zpc2NhbGVzIiwiZXhlcmNpY2VzIiwiY29udmVudGlvbnNfY29sbGVjdGl2ZXMiLCJiaWxhbnNfaW5waSIsImRvY3VtZW50c19hc3NvY2lhdGlvbiIsImNlcnRpZmljYXRfYWdlbmNlX2JpbyIsImJpbGFuc19lbnRyZXByaXNlX2JkZiIsImF0dGVzdGF0aW9uc19hZ2VmaXBoIiwibWVzcmlfaWRlbnRpZmlhbnQiLCJtZXNyaV9pZGVudGl0ZSIsIm1lc3JpX2luc2NyaXB0aW9uX2V0dWRpYW50IiwibWVzcmlfaW5zY3JpcHRpb25fYXV0cmUiLCJtZXNyaV9hZG1pc3Npb24iLCJtZXNyaV9ldGFibGlzc2VtZW50cyIsInBvbGVfZW1wbG9pX2lkZW50aXRlIiwicG9sZV9lbXBsb2lfYWRyZXNzZSIsInBvbGVfZW1wbG9pX2NvbnRhY3QiLCJwb2xlX2VtcGxvaV9pbnNjcmlwdGlvbiIsImNuYWZfcXVvdGllbnRfZmFtaWxpYWwiLCJjbmFmX2FsbG9jYXRhaXJlcyIsImNuYWZfZW5mYW50cyIsImNuYWZfYWRyZXNzZSIsImNub3VzX3N0YXR1dF9ib3Vyc2llciIsInVwdGltZSIsImNub3VzX2VjaGVsb25fYm91cnNlIiwiY25vdXNfZW1haWwiLCJjbm91c19wZXJpb2RlX3ZlcnNlbWVudCIsImNub3VzX3N0YXR1dF9ib3Vyc2UiLCJjbm91c192aWxsZV9ldHVkZXMiLCJjbm91c19pZGVudGl0ZSIsImRnZmlwX2RlY2xhcmFudDFfbm9tIiwiZGdmaXBfZGVjbGFyYW50MV9ub21fbmFpc3NhbmNlIiwiZGdmaXBfZGVjbGFyYW50MV9wcmVub21zIiwiZGdmaXBfZGVjbGFyYW50MV9kYXRlX25haXNzYW5jZSIsImRnZmlwX2RlY2xhcmFudDJfbm9tIiwiZGdmaXBfZGVjbGFyYW50Ml9ub21fbmFpc3NhbmNlIiwiZGdmaXBfZGVjbGFyYW50Ml9wcmVub21zIiwiZGdmaXBfZGVjbGFyYW50Ml9kYXRlX25haXNzYW5jZSIsImRnZmlwX2RhdGVfcmVjb3V2cmVtZW50IiwiZGdmaXBfZGF0ZV9ldGFibGlzc2VtZW50IiwiZGdmaXBfYWRyZXNzZV9maXNjYWxlX3RheGF0aW9uIiwiZGdmaXBfYWRyZXNzZV9maXNjYWxlX2FubmVlIiwiZGdmaXBfbm9tYnJlX3BhcnRzIiwiZGdmaXBfbm9tYnJlX3BlcnNvbm5lc19hX2NoYXJnZSIsImRnZmlwX3NpdHVhdGlvbl9mYW1pbGlhbGUiLCJkZ2ZpcF9yZXZlbnVfYnJ1dF9nbG9iYWwiLCJkZ2ZpcF9yZXZlbnVfaW1wb3NhYmxlIiwiZGdmaXBfaW1wb3RfcmV2ZW51X25ldF9hdmFudF9jb3JyZWN0aW9ucyIsImRnZmlwX21vbnRhbnRfaW1wb3QiLCJkZ2ZpcF9yZXZlbnVfZmlzY2FsX3JlZmVyZW5jZSIsImRnZmlwX2FubmVlX2ltcG90IiwiZGdmaXBfYW5uZWVfcmV2ZW51cyIsImRnZmlwX2VycmV1cl9jb3JyZWN0aWYiLCJkZ2ZpcF9zaXR1YXRpb25fcGFydGllbGxlIl0sInN1YiI6InN0YWdpbmcgZGV2ZWxvcG1lbnQiLCJpYXQiOjE2NjY4NjQwNzQsInZlcnNpb24iOiIxLjAiLCJleHAiOjE5ODI0ODMyNzR9.u2kMWzll3iCTczUOqMQbpS66VfrVzI2lLiyGEPcKAec" }

      it { is_expected.to eq(true) }
    end

    context "with a new token" do
      let(:token) { "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiI1MmE1YmZjMi1jMzUwLTQ4ZjQtYjY5Ni05ZWE3NmRiM2VmMjkiLCJqdGkiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJzY29wZXMiOlsiY2VydGlmaWNhdF9yZ2VfYWRlbWUiLCJtc2FfY290aXNhdGlvbnMiLCJlbnRyZXByaXNlcyIsImV4dHJhaXRzX3JjcyIsImNlcnRpZmljYXRfb3BxaWJpIiwiYXNzb2NpYXRpb25zIiwiZXRhYmxpc3NlbWVudHMiLCJmbnRwX2NhcnRlX3BybyIsInF1YWxpYmF0IiwiZW50cmVwcmlzZXNfYXJ0aXNhbmFsZXMiLCJjZXJ0aWZpY2F0X2NuZXRwIiwiZW9yaV9kb3VhbmVzIiwicHJvYnRwIiwiYWN0ZXNfaW5waSIsImV4dHJhaXRfY291cnRfaW5waSIsImF0dGVzdGF0aW9uc19zb2NpYWxlcyIsImxpYXNzZV9maXNjYWxlIiwiYXR0ZXN0YXRpb25zX2Zpc2NhbGVzIiwiZXhlcmNpY2VzIiwiY29udmVudGlvbnNfY29sbGVjdGl2ZXMiLCJiaWxhbnNfaW5waSIsImRvY3VtZW50c19hc3NvY2lhdGlvbiIsImNlcnRpZmljYXRfYWdlbmNlX2JpbyIsImJpbGFuc19lbnRyZXByaXNlX2JkZiIsImF0dGVzdGF0aW9uc19hZ2VmaXBoIiwibWVzcmlfaWRlbnRpZmlhbnQiLCJtZXNyaV9pZGVudGl0ZSIsIm1lc3JpX2luc2NyaXB0aW9uX2V0dWRpYW50IiwibWVzcmlfaW5zY3JpcHRpb25fYXV0cmUiLCJtZXNyaV9hZG1pc3Npb24iLCJtZXNyaV9ldGFibGlzc2VtZW50cyIsInBvbGVfZW1wbG9pX2lkZW50aXRlIiwicG9sZV9lbXBsb2lfYWRyZXNzZSIsInBvbGVfZW1wbG9pX2NvbnRhY3QiLCJwb2xlX2VtcGxvaV9pbnNjcmlwdGlvbiIsImNuYWZfcXVvdGllbnRfZmFtaWxpYWwiLCJjbmFmX2FsbG9jYXRhaXJlcyIsImNuYWZfZW5mYW50cyIsImNuYWZfYWRyZXNzZSIsImNub3VzX3N0YXR1dF9ib3Vyc2llciIsInVwdGltZSIsImNub3VzX2VjaGVsb25fYm91cnNlIiwiY25vdXNfZW1haWwiLCJjbm91c19wZXJpb2RlX3ZlcnNlbWVudCIsImNub3VzX3N0YXR1dF9ib3Vyc2UiLCJjbm91c192aWxsZV9ldHVkZXMiLCJjbm91c19pZGVudGl0ZSIsImRnZmlwX2RlY2xhcmFudDFfbm9tIiwiZGdmaXBfZGVjbGFyYW50MV9ub21fbmFpc3NhbmNlIiwiZGdmaXBfZGVjbGFyYW50MV9wcmVub21zIiwiZGdmaXBfZGVjbGFyYW50MV9kYXRlX25haXNzYW5jZSIsImRnZmlwX2RlY2xhcmFudDJfbm9tIiwiZGdmaXBfZGVjbGFyYW50Ml9ub21fbmFpc3NhbmNlIiwiZGdmaXBfZGVjbGFyYW50Ml9wcmVub21zIiwiZGdmaXBfZGVjbGFyYW50Ml9kYXRlX25haXNzYW5jZSIsImRnZmlwX2RhdGVfcmVjb3V2cmVtZW50IiwiZGdmaXBfZGF0ZV9ldGFibGlzc2VtZW50IiwiZGdmaXBfYWRyZXNzZV9maXNjYWxlX3RheGF0aW9uIiwiZGdmaXBfYWRyZXNzZV9maXNjYWxlX2FubmVlIiwiZGdmaXBfbm9tYnJlX3BhcnRzIiwiZGdmaXBfbm9tYnJlX3BlcnNvbm5lc19hX2NoYXJnZSIsImRnZmlwX3NpdHVhdGlvbl9mYW1pbGlhbGUiLCJkZ2ZpcF9yZXZlbnVfYnJ1dF9nbG9iYWwiLCJkZ2ZpcF9yZXZlbnVfaW1wb3NhYmxlIiwiZGdmaXBfaW1wb3RfcmV2ZW51X25ldF9hdmFudF9jb3JyZWN0aW9ucyIsImRnZmlwX21vbnRhbnRfaW1wb3QiLCJkZ2ZpcF9yZXZlbnVfZmlzY2FsX3JlZmVyZW5jZSIsImRnZmlwX2FubmVlX2ltcG90IiwiZGdmaXBfYW5uZWVfcmV2ZW51cyIsImRnZmlwX2VycmV1cl9jb3JyZWN0aWYiLCJkZ2ZpcF9zaXR1YXRpb25fcGFydGllbGxlIl0sInN1YiI6InN0YWdpbmcgZGV2ZWxvcG1lbnQiLCJpYXQiOjE2NjY4NjQwNzQsInZlcnNpb24iOiIxLjAiLCJleHAiOjE5ODI0ODMyNzR9.u2kMWzll3iCTczUOqMQbpS66VfrVzI2lLiyGEPcKAecx" }

      it { is_expected.to eq(true) }
    end

    context "with a nil token" do
      let(:token) { nil }

      it { is_expected.to eq(false) }
    end
  end

  describe "#expired?" do
    subject { api_entreprise_token.expired? }

    context "without token" do
      let(:token) { nil }

      it { is_expected.to eq(true) }
    end

    context "with a blank token" do
      let(:token) { "" }

      it { is_expected.to eq(true) }
    end

    context "with an invalid token" do
      let(:token) { "NOT-A-VALID-TOKEN" }

      it "log an error and return true" do
        allow(Rails.logger).to receive(:error)
        result = subject

        expect(Rails.logger).to have_received(:error).with(/Not enough or too many segments/)
        expect(result).to eq(true)
      end
    end

    context "with a valid not expiring token" do
      # never expire
      let(:token) { "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiI2NjRkZWEyMS02YWFlLTQwZmYtYWM0Mi1kZmQ3ZGE4YjQ3NmUiLCJqdGkiOiJhcGktZW50cmVwcmlzZS1zdGFnaW5nIiwicm9sZXMiOlsiY2VydGlmaWNhdF9jbmV0cCIsInByb2J0cCIsImV0YWJsaXNzZW1lbnRzIiwicHJpdmlsZWdlcyIsInVwdGltZSIsImF0dGVzdGF0aW9uc19hZ2VmaXBoIiwiYWN0ZXNfaW5waSIsImJpbGFuc19pbnBpIiwiYWlkZXNfY292aWRfZWZmZWN0aWZzIiwiY2VydGlmaWNhdF9yZ2VfYWRlbWUiLCJhdHRlc3RhdGlvbnNfc29jaWFsZXMiLCJlbnRyZXByaXNlX2FydGlzYW5hbGUiLCJmbnRwX2NhcnRlX3BybyIsImNvbnZlbnRpb25zX2NvbGxlY3RpdmVzIiwiZXh0cmFpdHNfcmNzIiwiZXh0cmFpdF9jb3VydF9pbnBpIiwiY2VydGlmaWNhdF9hZ2VuY2VfYmlvIiwibXNhX2NvdGlzYXRpb25zIiwiZG9jdW1lbnRzX2Fzc29jaWF0aW9uIiwiZW9yaV9kb3VhbmVzIiwiYXNzb2NpYXRpb25zIiwiYmlsYW5zX2VudHJlcHJpc2VfYmRmIiwiZW50cmVwcmlzZXMiLCJxdWFsaWJhdCIsImNlcnRpZmljYXRfb3BxaWJpIiwiZW50cmVwcmlzZSIsImV0YWJsaXNzZW1lbnQiXSwic3ViIjoic3RhZ2luZyBkZXZlbG9wbWVudCIsImlhdCI6MTY0MTMwNDcxNCwidmVyc2lvbiI6IjEuMCJ9.6GvMpHhPXmRuY06YMym-kp_67tQhgHxDys3YIH58ws8" }

      it { expect(subject).to be_falsey }
    end

    context "with a valid expiring token" do
      # expire on Jul 4, 2023 14:58:34
      let(:token) { "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiI2NjRkZWEyMS02YWFlLTQwZmYtYWM0Mi1kZmQ3ZGE4YjQ3NmUiLCJqdGkiOiJhcGktZW50cmVwcmlzZS1zdGFnaW5nIiwicm9sZXMiOlsiY2VydGlmaWNhdF9jbmV0cCIsInByb2J0cCIsImV0YWJsaXNzZW1lbnRzIiwicHJpdmlsZWdlcyIsInVwdGltZSIsImF0dGVzdGF0aW9uc19hZ2VmaXBoIiwiYWN0ZXNfaW5waSIsImJpbGFuc19pbnBpIiwiYWlkZXNfY292aWRfZWZmZWN0aWZzIiwiY2VydGlmaWNhdF9yZ2VfYWRlbWUiLCJhdHRlc3RhdGlvbnNfc29jaWFsZXMiLCJlbnRyZXByaXNlX2FydGlzYW5hbGUiLCJmbnRwX2NhcnRlX3BybyIsImNvbnZlbnRpb25zX2NvbGxlY3RpdmVzIiwiZXh0cmFpdHNfcmNzIiwiZXh0cmFpdF9jb3VydF9pbnBpIiwiY2VydGlmaWNhdF9hZ2VuY2VfYmlvIiwibXNhX2NvdGlzYXRpb25zIiwiZG9jdW1lbnRzX2Fzc29jaWF0aW9uIiwiZW9yaV9kb3VhbmVzIiwiYXNzb2NpYXRpb25zIiwiYmlsYW5zX2VudHJlcHJpc2VfYmRmIiwiZW50cmVwcmlzZXMiLCJxdWFsaWJhdCIsImNlcnRpZmljYXRfb3BxaWJpIiwiZW50cmVwcmlzZSIsImV0YWJsaXNzZW1lbnQiXSwic3ViIjoic3RhZ2luZyBkZXZlbG9wbWVudCIsImlhdCI6MTY0MTMwNDcxNCwidmVyc2lvbiI6IjEuMCIsImV4cCI6MTY4ODQ3NTUxNH0.xID66pIlMnBR5_6nG-GidFBzK4Tuuy5ZsWfkMEVB_Ek" }

      it "must be false when token has not expired yet" do
        travel_to Time.zone.local(2021) do
          expect(subject).to be_falsey
        end
      end

      it "must be true when token has expired" do
        travel_to Time.zone.local(2025) do
          expect(subject).to be_truthy
        end
      end
    end
  end

  describe "#expires_at" do
    subject { api_entreprise_token.expires_at }

    context "without token" do
      let(:token) { nil }

      it { is_expected.to be_nil }
    end

    context "with a blank token" do
      let(:token) { "" }

      it { is_expected.to be_nil }
    end

    context "with an invalid token" do
      let(:token) { "NOT-A-VALID-TOKEN" }

      it "log an error and return nil" do
        allow(Rails.logger).to receive(:error)
        result = subject

        expect(Rails.logger).to have_received(:error).with(/Not enough or too many segments/)
        expect(result).to be_nil
      end
    end

    context "with a valid token" do
      let(:token) { "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiI2NjRkZWEyMS02YWFlLTQwZmYtYWM0Mi1kZmQ3ZGE4YjQ3NmUiLCJqdGkiOiJhcGktZW50cmVwcmlzZS1zdGFnaW5nIiwicm9sZXMiOlsiY2VydGlmaWNhdF9jbmV0cCIsInByb2J0cCIsImV0YWJsaXNzZW1lbnRzIiwicHJpdmlsZWdlcyIsInVwdGltZSIsImF0dGVzdGF0aW9uc19hZ2VmaXBoIiwiYWN0ZXNfaW5waSIsImJpbGFuc19pbnBpIiwiYWlkZXNfY292aWRfZWZmZWN0aWZzIiwiY2VydGlmaWNhdF9yZ2VfYWRlbWUiLCJhdHRlc3RhdGlvbnNfc29jaWFsZXMiLCJlbnRyZXByaXNlX2FydGlzYW5hbGUiLCJmbnRwX2NhcnRlX3BybyIsImNvbnZlbnRpb25zX2NvbGxlY3RpdmVzIiwiZXh0cmFpdHNfcmNzIiwiZXh0cmFpdF9jb3VydF9pbnBpIiwiY2VydGlmaWNhdF9hZ2VuY2VfYmlvIiwibXNhX2NvdGlzYXRpb25zIiwiZG9jdW1lbnRzX2Fzc29jaWF0aW9uIiwiZW9yaV9kb3VhbmVzIiwiYXNzb2NpYXRpb25zIiwiYmlsYW5zX2VudHJlcHJpc2VfYmRmIiwiZW50cmVwcmlzZXMiLCJxdWFsaWJhdCIsImNlcnRpZmljYXRfb3BxaWJpIiwiZW50cmVwcmlzZSIsImV0YWJsaXNzZW1lbnQiXSwic3ViIjoic3RhZ2luZyBkZXZlbG9wbWVudCIsImlhdCI6MTY0MTMwNDcxNCwidmVyc2lvbiI6IjEuMCIsImV4cCI6MTY4ODQ3NTUxNH0.xID66pIlMnBR5_6nG-GidFBzK4Tuuy5ZsWfkMEVB_Ek" }

      it "returns the correct expiration time" do
        expect(subject).to eq(Time.zone.at(1688475514))
      end
    end
  end

  describe "#needs_renewal?" do
    subject { api_entreprise_token.needs_renewal? }

    context "when there is no token" do
      let(:token) { nil }

      it { is_expected.to be_falsey }
    end

    context "when the token expires in 2 months" do
      let(:token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, "none") }

      it { is_expected.to be_falsey }
    end

    context "when the token expires tomorrow" do
      let(:token) { JWT.encode({ exp: 1.day.from_now.to_i }, nil, "none") }

      it { is_expected.to be_truthy }
    end

    context "when the token is expired" do
      let(:token) { JWT.encode({ exp: 1.day.ago.to_i }, nil, "none") }

      it { is_expected.to be_truthy }
    end

    context "when the token cannot be decoded" do
      let(:token) { "azertyuiopqsdfgh" }

      it { is_expected.to be_truthy }
    end
  end
end
