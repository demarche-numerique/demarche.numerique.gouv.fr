# frozen_string_literal: true

RSpec.describe AvisMailer, type: :mailer do
  describe ".avis_invitation_and_confirm_email" do
    let_it_be(:procedure) { procedures.individual }
    let_it_be(:dossier, reload: true) { create(:dossier, :en_instruction, procedure: procedure) }
    let_it_be(:dossier2, reload: true) { create(:dossier, :en_instruction, procedure: procedure) }
    let_it_be(:expert) { experts.default }
    let_it_be(:experts_procedure) { experts_procedures.default }
    let_it_be(:avis1, reload: true) { create(:avis, dossier: dossier, experts_procedure: experts_procedure) }
    let(:avis2) { create(:avis, dossier: dossier2, experts_procedure: experts_procedure) }

    let(:user) { create(:user, confirmation_token: "token") }

    let(:mail) do
      described_class
        .avis_invitation_and_confirm_email(user, user.confirmation_token, avis_param)
        .deliver_now
    end

    def check_targeted_link
      mail # force rendering
      link = TargetedUserLink.last
      expect(link).not_to be_nil
      expect(mail.html_part.body.to_s).to include("/targeted_user_links/#{link.id}")
    end

    context "with single avis" do
      let(:avis_param) { avis1 }

      context "when user is active and verified" do
        let(:user) { create(:user, :active, :with_email_verified, confirmation_token: "token") }

        it "does not include confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).not_to include("confirmation_token=")
            check_targeted_link
          end
        end
      end

      context "when user is inactive" do
        let(:user) { create(:user, :inactive, confirmation_token: "token") }

        it "includes confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).to include("confirmation_token=token")
            check_targeted_link
          end
        end
      end

      context "when user is active but unverified" do
        let(:user) { create(:user, :active, email_verified_at: nil, confirmation_token: "token") }

        it "includes confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).to include("confirmation_token=token")
            check_targeted_link
          end
        end
      end
    end

    context "with multiple avis" do
      let(:avis_param) { [avis1, avis2] }

      context "when user is active and verified" do
        let(:user) { create(:user, :active, :with_email_verified, confirmation_token: "token") }

        it "does not include confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).not_to include("confirmation_token=")
            check_targeted_link
          end
        end
      end

      context "when user is inactive" do
        let(:user) { create(:user, :inactive, confirmation_token: "token") }

        it "includes confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).to include("confirmation_token=token")
            check_targeted_link
          end
        end
      end

      context "when user is active but unverified" do
        let(:user) { create(:user, :active, email_verified_at: nil, confirmation_token: "token") }

        it "includes confirmation_token and includes targeted link" do
          aggregate_failures do
            expect(mail.html_part.body.to_s).to include("confirmation_token=token")
            check_targeted_link
          end
        end
      end

      context "when all dossiers are hidden" do
        let(:user) { create(:user, :active, :with_email_verified, confirmation_token: "token") }

        before do
          dossier.update!(hidden_by_administration_at: 1.hour.ago)
          dossier2.update!(hidden_by_administration_at: 1.hour.ago)
        end

        it "does not send the email" do
          result = described_class
            .avis_invitation_and_confirm_email(user, user.confirmation_token, avis_param)

          expect(result.message).to be_a(ActionMailer::Base::NullMail)
        end
      end
    end
  end

  describe ".notify_new_commentaire_to_expert" do
    subject do
      described_class
        .notify_new_commentaire_to_expert(avis.pending.dossier, avis.pending, experts.default)
        .deliver_now
    end

    it "is addressed to the expert" do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([experts.default.email])
    end

    it "sends nothing once the avis itself is revoked" do
      avis.pending.update!(answer: "Avis favorable", revoked_at: Time.zone.now)

      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end

    it "sends nothing once the expert is revoked from the procedure" do
      procedures.individual.update!(experts_require_administrateur_invitation: true)
      experts_procedures.default.update!(revoked_at: Time.zone.now)

      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
