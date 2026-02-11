# frozen_string_literal: true

require 'rake'
TPS::Application.load_tasks if Rake::Task.tasks.empty?

describe 'support' do
  describe 'remove_ex_team_member' do
    let(:rake_task) { Rake::Task['support:remove_ex_team_member'] }

    subject do
      ENV['SUPER_ADMIN_EMAIL'] = super_admin.email
      ENV['USER_EMAIL'] = admin.email
      rake_task.invoke
    end
    after { rake_task.reenable }

    # the admin to remove
    let(:admin) { administrateurs(:default_admin) }

    # the super admin doing the removal
    let(:super_admin) { create(:super_admin) }
    let!(:super_admin_admin) { create(:administrateur, email: super_admin.email) }

    context 'an empty procedure is discarded' do
      let!(:empty_procedure) { create(:procedure, :published, administrateur: admin) }

      it do
        subject
        expect(admin.procedures).to be_empty
        expect(admin.procedures.with_discarded.discarded).to match_array(empty_procedure)
      end
    end

    context 'a procedure only with the admins dossiers is discarded' do
      let!(:procedure_with_admin_dossiers) { create(:procedure, :published, administrateur: admin) }
      let!(:admin_instruction_dossier) { create(:dossier, :en_instruction, procedure: procedure_with_admin_dossiers, user: admin.user) }
      let!(:admin_termine_dossier) { create(:dossier, :accepte, procedure: procedure_with_admin_dossiers, user: admin.user) }

      it do
        subject
        expect(admin.procedures).to be_empty
        expect(admin.procedures.with_discarded.discarded).to match_array(procedure_with_admin_dossiers)
        expect { admin_instruction_dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(admin_termine_dossier.reload.user).to be_nil
      end
    end

    context 'a procedure only with others dossiers is kept' do
      let!(:procedure_with_dossiers) { create(:procedure, :published, administrateur: admin) }
      let!(:admin_dossier) { create(:dossier, :en_instruction, procedure: procedure_with_dossiers, user: admin.user) }
      let!(:another_dossier) { create(:dossier, :en_instruction, procedure: procedure_with_dossiers) }

      it do
        subject
        expect(admin.procedures).to match_array(procedure_with_dossiers)
        expect { admin_dossier.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'a procedure shared with another admin' do
      let!(:another_admin) { create(:administrateur) }
      let!(:shared_procedure) { create(:procedure, :published, administrateurs: [admin, another_admin]) }

      it do
        subject
        expect(admin.procedures).to be_empty
        expect(another_admin.procedures).to match_array(shared_procedure)
      end
    end
  end
end
