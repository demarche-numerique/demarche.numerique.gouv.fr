# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260903BackfillAPITokenExpiresAtTask do
    let(:administrateur) { administrateurs.blank }
    let(:expires_on) { APIToken.max_expires_at }

    subject(:process) { described_class.new.process(administrateur) }

    def eternal_token(version: 3)
      APIToken.generate(administrateur).first.tap do |token|
        token.update_columns(expires_at: nil, version:)
      end
    end

    it "date les jetons éternels" do
      token = eternal_token

      expect { process }.to change { token.reload.expires_at }.from(nil).to(expires_on)
    end

    it "ne touche pas un jeton déjà daté" do
      dated = APIToken.generate(administrateur, expires_at: 1.week.from_now.to_date).first

      expect { process }.not_to change { dated.reload.expires_at }
    end

    it "n’envoie qu’un seul courriel à un administrateur détenant plusieurs jetons" do
      3.times { eternal_token }

      expect { process }.to have_enqueued_mail(APITokenMailer, :becomes_expirable).once
    end

    # Les jetons v1/v2 ne peuvent plus s’authentifier : on les date sans prévenir.
    it "date les jetons inertes sans prévenir leur propriétaire" do
      token = eternal_token(version: 1)

      expect { process }.not_to have_enqueued_mail(APITokenMailer, :becomes_expirable)
      expect(token.reload.expires_at).to eq(expires_on)
    end

    it "ne prévient que pour les jetons encore capables de s’authentifier" do
      eternal_token(version: 1)
      live = eternal_token(version: 3)

      expect { process }.to have_enqueued_mail(APITokenMailer, :becomes_expirable)
        .with(administrateur.user, [live], expires_on)
    end

    it "ignore un administrateur sans utilisateur exploitable" do
      token = eternal_token
      allow(administrateur).to receive(:user).and_return(nil)

      expect { process }.not_to raise_error
      expect(token.reload.expires_at).to eq(expires_on)
    end

    describe "#collection" do
      it "ne retient que les administrateurs ayant au moins un jeton éternel" do
        eternal_token

        expect(described_class.new.collection).to include(administrateur)
      end

      it "écarte un administrateur dont tous les jetons sont datés" do
        APIToken.generate(administrateur, expires_at: 1.week.from_now.to_date)

        expect(described_class.new.collection).not_to include(administrateur)
      end
    end
  end
end
