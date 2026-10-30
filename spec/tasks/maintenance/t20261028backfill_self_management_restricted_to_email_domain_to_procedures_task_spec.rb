# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261028backfillSelfManagementRestrictedToEmailDomainToProceduresTask do
    describe "#collection" do
      subject(:collection) { described_class.collection }

      let!(:self_managed_procedure) { create(:procedure, instructeurs_self_management_enabled: true) }
      let!(:admin_managed_procedure) { create(:procedure, instructeurs_self_management_enabled: false) }
      let!(:hidden_self_managed_procedure) { create(:procedure, :discarded, instructeurs_self_management_enabled: true) }

      it "only includes procedures with self management enabled, hidden ones included" do
        expect(collection).to include(self_managed_procedure, hidden_self_managed_procedure)
        expect(collection).not_to include(admin_managed_procedure)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      let(:procedure) { create(:procedure, instructeurs_self_management_enabled: true, instructeurs:) }

      context "when instructeurs have different email domains" do
        let(:instructeurs) do
          [
            create(:instructeur, email: "agent@interieur.gouv.fr"),
            create(:instructeur, email: "agent@ars.sante.fr"),
          ]
        end

        it "lifts the email domain restriction" do
          expect { process }.to change { procedure.reload.self_management_restricted_to_email_domain }.from(true).to(false)
        end
      end

      context "when instructeurs share the same email domain" do
        let(:instructeurs) do
          [
            create(:instructeur, email: "agent1@interieur.gouv.fr"),
            create(:instructeur, email: "agent2@interieur.gouv.fr"),
          ]
        end

        it "keeps the email domain restriction" do
          expect { process }.not_to change { procedure.reload.self_management_restricted_to_email_domain }
        end
      end

      context "when instructeurs with different email domains are spread across groupes" do
        let(:instructeurs) { [create(:instructeur, email: "agent@interieur.gouv.fr")] }

        before do
          other_groupe = create(:groupe_instructeur, procedure:)
          other_groupe.add_instructeurs(emails: ["agent@ars.sante.fr"])
        end

        it "lifts the email domain restriction" do
          expect { process }.to change { procedure.reload.self_management_restricted_to_email_domain }.from(true).to(false)
        end
      end
    end
  end
end
