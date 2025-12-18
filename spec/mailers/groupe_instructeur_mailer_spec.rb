# frozen_string_literal: true

RSpec.describe GroupeInstructeurMailer, type: :mailer do
  describe '#notify_removed_instructeur' do
    let(:procedure) { create(:procedure) }
    let(:groupe_instructeur) do
      gi = GroupeInstructeur.create(label: 'gi1', procedure: procedure)
      gi.instructeurs << create(:instructeur, email: 'int1@g.fr')
      gi.instructeurs << create(:instructeur, email: 'int2@g.fr')
      gi.instructeurs << instructeur_to_remove
      gi
    end
    let(:instructeur_to_remove) { create(:instructeur, email: 'int3@g.fr') }

    let(:current_instructeur_email) { 'toto@email.com' }

    subject { described_class.notify_removed_instructeur(groupe_instructeur, instructeur_to_remove, current_instructeur_email) }

    before { groupe_instructeur.remove(instructeur_to_remove) }

    context 'when instructeur is fully removed form procedure' do
      it do
        expect(subject.body).to include('Vous avez été désaffecté(e) de la démarche')
        expect(subject.to).to include('int3@g.fr')
        expect(subject.to).not_to include('int1@g.fr', 'int2@g.fr')
      end
    end

    context 'when instructeur is removed from one group but still affected to procedure' do
      let!(:groupe_instructeur_2) do
        gi2 = GroupeInstructeur.create(label: 'gi2', procedure: procedure)
        gi2.instructeurs << instructeur_to_remove
        gi2
      end

      it do
        expect(subject.body).to include('Vous avez été retiré(e) du groupe « gi1 » par « toto@email.com »')
        expect(subject.to).to include('int3@g.fr')
        expect(subject.to).not_to include('int1@g.fr', 'int2@g.fr')
      end
    end
  end

  describe '#notify_added_instructeurs' do
    let(:procedure) { create(:procedure) }

    let(:instructeurs_to_add) { [create(:instructeur, email: 'int3@g.fr'), create(:instructeur, email: 'int4@g.fr')] }

    let(:current_instructeur_email) { 'toto@email.com' }

    subject { described_class.notify_added_instructeurs(procedure.defaut_groupe_instructeur, instructeurs_to_add, current_instructeur_email) }

    before { instructeurs_to_add.each { procedure.defaut_groupe_instructeur.add(_1) } }

    context 'when there is only one group on procedure' do
      it do
        expect(subject.body).to include('Vous avez été affecté(e) à la démarche')
        expect(subject.bcc).to match_array(['int3@g.fr', 'int4@g.fr'])
      end
    end

    context 'when there are many groups on procedure' do
      let!(:groupe_instructeur_2) do
        GroupeInstructeur.create(label: 'gi2', procedure: procedure)
      end
      it do
        expect(subject.body).to include('Vous avez été ajouté(e) au groupe')
        expect(subject.bcc).to match_array(['int3@g.fr', 'int4@g.fr'])
      end
    end
  end

  describe '#notify_added_instructeur_from_groupes_import' do
    let(:procedure) { create(:procedure) }
    let(:groupe_instructeur_1) { create(:groupe_instructeur, procedure: procedure, label: 'Groupe 1') }
    let(:groupe_instructeur_2) { create(:groupe_instructeur, procedure: procedure, label: 'Groupe 2') }
    let(:instructeur) { create(:instructeur, email: 'instructeur@test.fr') }
    let(:current_instructeur_email) { 'admin@test.fr' }

    subject { described_class.notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email) }

    context 'when assigned to one group' do
      let(:groups) { [groupe_instructeur_1] }

      it 'sends email with correct subject and content' do
        expect(subject.to).to eq(['instructeur@test.fr'])
        expect(subject.subject).to include('Vous avez été affecté(e) au groupe instructeur « Groupe 1 »')
        expect(subject.subject).to include(procedure.libelle)
        expect(subject.body).to include('Vous avez été affecté(e) au groupe instructeur « Groupe 1 »')
        expect(subject.body).to include(procedure.libelle)
        expect(subject.body).to include('admin@test.fr')
      end
    end

    context 'when assigned to many groups' do
      let(:groups) { [groupe_instructeur_1, groupe_instructeur_2] }

      it 'sends email with correct subject and content for many groups' do
        expect(subject.to).to eq(['instructeur@test.fr'])
        expect(subject.subject).to include('Vous avez été affecté(e) à 2 groupes instructeurs')
        expect(subject.subject).to include(procedure.libelle)
        expect(subject.body).to include('Vous avez été affecté(e) à 2 groupes instructeurs')
        expect(subject.body).to include('Groupe 1')
        expect(subject.body).to include('Groupe 2')
        expect(subject.body).to include('admin@test.fr')
      end
    end
  end

  describe '#confirm_and_notify_added_instructeur_from_groupes_import' do
    let(:procedure) { create(:procedure) }
    let(:groupe_instructeur_1) { create(:groupe_instructeur, procedure: procedure, label: 'Groupe 1') }
    let(:groupe_instructeur_2) { create(:groupe_instructeur, procedure: procedure, label: 'Groupe 2') }
    let(:instructeur) { create(:instructeur, email: 'instructeur@test.fr') }
    let(:current_instructeur_email) { 'admin@test.fr' }

    subject { described_class.confirm_and_notify_added_instructeur_from_groupes_import(instructeur, groups, current_instructeur_email) }

    context 'when assigned to one group' do
      let(:groups) { [groupe_instructeur_1] }

      it 'sends email with correct subject and includes reset password token' do
        expect(subject.to).to eq(['instructeur@test.fr'])
        expect(subject.subject).to include('Vous avez été affecté(e) au groupe "Groupe 1"')
        expect(subject.subject).to include(procedure.libelle)
        expect(instructeur.user.reset_password_token).to be_present
      end
    end

    context 'when assigned to many groups' do
      let(:groups) { [groupe_instructeur_1, groupe_instructeur_2] }

      it 'sends email with correct subject for many groups and includes reset password token' do
        expect(subject.to).to eq(['instructeur@test.fr'])
        expect(subject.subject).to include('Vous avez été affecté(e) à 2 groupes')
        expect(subject.subject).to include(procedure.libelle)
        expect(instructeur.user.reset_password_token).to be_present
      end
    end
  end
end
