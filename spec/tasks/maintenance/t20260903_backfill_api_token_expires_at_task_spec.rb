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

    # Les dater ne doit pas les faire entrer dans les relances : sans quoi le cron
    # enverrait trois courriels par jeton mort, onze mois plus tard.
    it "ne fait pas entrer les jetons inertes dans les relances" do
      token = eternal_token(version: 1)
      process

      [1.month, 1.week, 1.day].each do |window|
        travel_to(token.reload.expires_at - window) do
          expect(APIToken.with_expiration_notice_to_send_for(window)).not_to include(token)
        end
      end
    end

    it "ne prévient que pour les jetons encore capables de s’authentifier" do
      eternal_token(version: 1)
      live = eternal_token(version: 3)

      expect { process }.to have_enqueued_mail(APITokenMailer, :becomes_expirable)
        .with(administrateur.user, [live], expires_on)
    end

    # Sans étalement, tous les courriels partiraient à la seconde où la tâche
    # tourne. Le tirage est figé pour que l’assertion porte sur la fenêtre
    # utilisée, pas sur une heure au hasard.
    it "étale l’envoi sur SPREAD_DURATION" do
      eternal_token
      task = described_class.new
      allow(task).to receive(:rand).with(0..described_class::SPREAD_DURATION).and_return(42.minutes)

      freeze_time do
        expect { task.process(administrateur) }
          .to have_enqueued_mail(APITokenMailer, :becomes_expirable).at(42.minutes.from_now)
      end
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
