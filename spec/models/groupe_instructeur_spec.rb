# frozen_string_literal: true

describe GroupeInstructeur, type: :model do
  let(:admin) { create :administrateur }
  let(:procedure) { create :procedure, :published, administrateur: admin }
  let(:procedure_2) { create :procedure, :published, administrateur: admin }
  let(:procedure_3) { create :procedure, :published, administrateur: admin }
  let(:instructeur) { create :instructeur, administrateurs: [admin] }
  let(:procedure_assign) { assign(procedure) }

  before do
    procedure_assign
    assign(procedure_2)
    procedure_3
  end

  subject { GroupeInstructeur.new(label: label, procedure: procedure) }

  context 'with no label provided' do
    let(:label) { '' }

    it { is_expected.to be_invalid }
  end

  context 'with a valid label' do
    let(:label) { 'Préfecture de la Marne' }

    it { is_expected.to be_valid }
  end

  context 'with a label with extra spaces' do
    let(:label) { 'Préfecture de la Marne      ' }
    before do
      subject.save
      subject.reload
    end

    it do
      is_expected.to be_valid
      expect(subject.label).to eq("Préfecture de la Marne")
    end
  end

  context 'with a label already used for this procedure' do
    let(:label) { 'Préfecture de la Marne' }
    before do
      GroupeInstructeur.create!(label: label, procedure: procedure)
    end

    it { is_expected.to be_invalid }
  end

  describe "#add" do
    let(:another_groupe_instructeur) { create(:groupe_instructeur, procedure: procedure) }

    subject { another_groupe_instructeur.add(instructeur) }

    it 'adds the instructeur to the groupe instructeur' do
      subject
      expect(another_groupe_instructeur.reload.instructeurs).to include(instructeur)
    end

    context "when the new instructeur has 'all' preferences for notifications" do
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:, display_dossier_modifie_notifications: 'all') }
      let!(:dossier) { create(:dossier, :en_construction, groupe_instructeur: another_groupe_instructeur, procedure:, last_champ_updated_at: Time.zone.now, depose_at: Time.zone.yesterday) }

      it "creates notifications on dossiers of the new groupe" do
        subject
        expect(DossierNotification.count).to eq(2)

        expect(DossierNotification.all.map(&:dossier_id).uniq).to eq([dossier.id])
        expect(DossierNotification.all.map(&:instructeur_id).uniq).to eq([instructeur.id])
        expect(DossierNotification.all.map(&:notification_type)).to match_array(['dossier_depose', 'dossier_modifie'])
      end
    end
  end

  describe "#remove" do
    subject { procedure_to_remove.defaut_groupe_instructeur.remove(instructeur) }

    context "with an assigned procedure" do
      let(:procedure_to_remove) { procedure }
      let!(:procedure_presentation) { procedure_assign.procedure_presentation }

      it { is_expected.to be_truthy }

      describe "consequences" do
        before do
          procedure_assign.build_procedure_presentation
          procedure_assign.save
          subject
        end

        it "removes the assign_to and procedure_presentation" do
          expect(AssignTo.where(id: procedure_assign).count).to eq(0)
          expect(ProcedurePresentation.where(assign_to_id: procedure_assign.id).count).to eq(0)
        end
      end
    end

    context "with an already unassigned procedure" do
      let(:procedure_to_remove) { procedure_3 }

      it { is_expected.to be_falsey }
    end

    context "when there are notifications for the instructeur" do
      let(:procedure_to_remove) { procedure }
      let(:groupe_instructeur) { procedure_to_remove.defaut_groupe_instructeur }
      let!(:dossier) { create(:dossier, groupe_instructeur:) }
      let!(:other_instructeur) { create(:instructeur) }
      let!(:notification_instructeur) { create(:dossier_notification, dossier:, instructeur:) }
      let!(:notification_other_instructeur) { create(:dossier_notification, dossier:, instructeur: other_instructeur) }

      before { procedure_to_remove.defaut_groupe_instructeur.add(other_instructeur) }

      it "destroy notifications only for the instructeur removed" do
        subject

        expect(
          DossierNotification.exists?(instructeur:, dossier:)
        ).to be_falsey

        expect(
          DossierNotification.exists?(instructeur: other_instructeur, dossier:)
        ).to be_truthy
      end
    end

    context "when there is an instructeurs_procedure" do
      let(:procedure_to_remove) { procedure }
      let!(:instructeur_procedure) { create(:instructeurs_procedure, instructeur:, procedure:) }

      context "when the instructeur is only in one group" do
        it "destroys the instructeurs_procedure" do
          subject

          expect(InstructeursProcedure.exists?(instructeur:, procedure:)).to be_falsey
        end
      end

      context "when the instructeur is in many groups" do
        let(:procedure_to_remove) { procedure }
        let!(:another_groupe_instructeur) { create(:groupe_instructeur, procedure:, instructeurs: [instructeur]) }

        it "does not destroy the instructeurs_procedure" do
          subject

          expect(InstructeursProcedure.exists?(instructeur:, procedure:)).to be_truthy
        end
      end
    end
  end

  describe "active group validations" do
    let(:gi_active) { procedure.defaut_groupe_instructeur }
    let(:gi_closed) { create(:groupe_instructeur, procedure:) }

    before do
      gi_active
      gi_closed.update(closed: true)
    end

    context "there is one active groupe instructeur" do
      it "closed is valid when there is one other active groupe" do
        expect(gi_active).to be_valid
        expect(gi_closed).to be_valid
      end

      it "closed is invalid when there is no active groupe" do
        gi_active.closed = true
        expect(gi_active).not_to be_valid
      end
    end

    context "there are many active groupes instructeurs" do
      let!(:second_gi_active) { create(:groupe_instructeur, procedure:) }

      it "closed is invalid for defaut groupe instructeur even if many active groupes" do
        gi_active.update(closed: true)
        expect(gi_active).not_to be_valid
      end
    end
  end

  describe 'destroy' do
    context 'with contact information' do
      let(:defaut_group) { procedure.defaut_groupe_instructeur }
      let(:second_group) { create(:groupe_instructeur, procedure:) }

      before do
        second_group.update(contact_information: create(:contact_information))
      end

      it 'works' do
        expect { second_group.destroy! }.not_to raise_error
      end
    end
  end

  describe 'routing rule validity' do
    include Logic

    let(:routed_procedure) { create(:procedure, :published, routing_enabled: true, administrateur: admin) }
    let(:stable_id) { routed_procedure.published_revision.types_de_champ_public.last.stable_id }

    before do
      routed_procedure.draft_revision.add_type_de_champ(
        type_champ: :drop_down_list,
        libelle: 'Ville',
        drop_down_options: ['Paris', 'Lyon', 'Marseille']
      )
      routed_procedure.publish_revision!(admin)
    end

    describe '#valid_rule?' do
      context 'with valid routing rule' do
        let(:gi) do
          create(:groupe_instructeur,
                 procedure: routed_procedure,
                 routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
        end

        it 'returns true for valid routing rule' do
          expect(gi.valid_rule?).to be true
        end
      end

      context 'with invalid routing rule (unknown stable_id)' do
        let(:gi) do
          create(:groupe_instructeur,
                 procedure: routed_procedure,
                 routing_rule: ds_eq(champ_value(999), constant('Paris')))
        end

        it 'returns false for invalid routing rule' do
          expect(gi.valid_rule?).to be false
        end
      end

      context 'with nil routing rule' do
        let(:gi) do
          create(:groupe_instructeur,
                 procedure: routed_procedure,
                 routing_rule: nil)
        end

        it 'returns false for nil routing rule' do
          expect(gi.valid_rule?).to be false
        end
      end
    end

    describe '#update_rule_statuses' do
      let!(:gi) do
        create(:groupe_instructeur,
               procedure: routed_procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
      end

      it 'updates valid_routing_rule for this groupe instructeur' do
        expect { gi.update_rule_statuses }
          .to change { gi.reload.valid_routing_rule }.from(false).to(true)
      end

      it 'updates unique_routing_rule for this groupe instructeur' do
        expect { gi.update_rule_statuses }
          .to change { gi.reload.unique_routing_rule }.from(false).to(true)
      end
    end

    describe '#groups_with_same_rule' do
      let(:routing_rule) { ds_eq(champ_value(1), constant('A')) }
      let!(:gi1) { create(:groupe_instructeur, procedure:, routing_rule:) }
      let!(:gi2) { create(:groupe_instructeur, procedure:, routing_rule:) }

      it 'finds groups with same rule' do
        expect(gi1.groups_with_same_rule).to include(gi2.label)
      end
    end
  end

  private

  def assign(procedure_to_assign, instructeur_assigne: instructeur)
    create :assign_to, instructeur: instructeur_assigne, procedure: procedure_to_assign, groupe_instructeur: procedure_to_assign.defaut_groupe_instructeur
  end
end
