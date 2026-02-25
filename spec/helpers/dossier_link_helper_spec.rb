# frozen_string_literal: true

describe DossierLinkHelper do
  describe "#dossier_linked_path" do
    context "when no access as a instructeur" do
      let(:instructeur) { create(:instructeur) }
      let(:dossier) { create(:dossier) }

      it { expect(helper.dossier_linked_path(instructeur, dossier)).to be_nil }
    end

    context "when no access as a user" do
      let(:user) { create(:user) }
      let(:dossier) { create(:dossier) }

      it { expect(helper.dossier_linked_path(user, dossier)).to be_nil }
    end

    context "when access as instructeur" do
      let(:procedure) { create(:procedure, :routee) }
      let(:dossier) { create(:dossier, groupe_instructeur: procedure.groupe_instructeurs.last) }
      let(:instructeur) { create(:instructeur) }

      before { procedure.groupe_instructeurs.last.instructeurs << instructeur }

      it { expect(helper.dossier_linked_path(instructeur, dossier)).to eq(instructeur_dossier_path(dossier.procedure, dossier)) }
    end

    context "when access as user" do
      let(:dossier) { create(:dossier) }
      let(:user) { create(:user) }

      before { dossier.user = user }

      it { expect(helper.dossier_linked_path(user, dossier)).to eq(dossier_path(dossier)) }
    end
  end

  describe "#deleted_dossier_show_summary" do
    let(:procedure) { create(:procedure, :published, libelle: 'Ma démarche') }
    let(:deleted_dossier) { create(:deleted_dossier, procedure:, depose_at: Date.new(2024, 3, 15), deleted_at: Time.zone.local(2024, 6, 1), reason: DeletedDossier.reasons.fetch(:user_request)) }

    it "returns a summary with depose_at, procedure name, reason and deleted_at" do
      summary = helper.deleted_dossier_show_summary(deleted_dossier)
      expect(summary).to include("Ma démarche")
      expect(summary).to include("supprimé")
      expect(summary).to include("15 mars 2024")
      expect(summary).to include("01 juin 2024")
    end

    context "when reason is expired" do
      let(:deleted_dossier) { create(:deleted_dossier, procedure:, depose_at: Date.new(2024, 3, 15), deleted_at: Time.zone.local(2024, 6, 1), reason: DeletedDossier.reasons.fetch(:expired)) }

      it "shows 'expiré' as reason" do
        summary = helper.deleted_dossier_show_summary(deleted_dossier)
        expect(summary).to include("expiré")
      end
    end

    context "when depose_at is nil" do
      let(:deleted_dossier) { create(:deleted_dossier, procedure:, depose_at: nil, deleted_at: Time.zone.local(2024, 6, 1)) }

      it "omits the deposit date" do
        summary = helper.deleted_dossier_show_summary(deleted_dossier)
        expect(summary).to include("Dossier sur la démarche")
        expect(summary).not_to include("déposé le")
      end
    end
  end
end
