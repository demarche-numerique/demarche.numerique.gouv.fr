# frozen_string_literal: true

require 'rake'
TPS::Application.load_tasks if Rake::Task.tasks.empty?

describe 'service tasks' do
  let(:rake_task) { Rake::Task[task] }
  subject { rake_task.invoke }
  after(:each) do
    rake_task.reenable
  end

  describe 'service:remove_orphans' do
    let(:task) { 'service:remove_orphans' }
    let(:service) { create(:service) }
    let(:procedure) { create(:procedure, :with_service) }
    let(:service_with_procedure) { procedure.service }
    it 'remove orphans' do
      service
      service_with_procedure

      subject

      expect(Service.find_by(id: service.id)).to be_nil
      expect(Service.find_by(id: service_with_procedure.id)).to eq service_with_procedure
    end
  end

  describe 'service:notify_no_siret' do
    let(:task) { 'service:email_no_siret' }
    let!(:procedure_without_siret_service) { create(:procedure, :published, service: service, administrateur: administrateur) }
    let(:administrateur) { administrateurs(:default_admin) }
    let(:service) do
      s = build(:service, siret: nil, administrateur: administrateur)
      s.save(validate: false)
      s
    end
    let!(:procedure_with_siret_service) { create(:procedure, :published, service: siret_service, administrateur: administrateur_with_siret_service) }
    let(:siret_service) { create(:service, administrateur: administrateur_with_siret_service) }
    let(:administrateur_with_siret_service) { create(:administrateur) }

    it 'emails admins with published procedures with services without siret' do
      message = double("message")
      allow(message).to receive(:deliver_later)
      allow(AdministrateurMailer).to receive(:notify_service_without_siret).with(administrateur.email).and_return(message)
      allow(AdministrateurMailer).to receive(:notify_service_without_siret).with(administrateur_with_siret_service.email).and_return(message)

      subject

      expect(AdministrateurMailer).to have_received(:notify_service_without_siret).with(administrateur.email).once
      expect(AdministrateurMailer).not_to have_received(:notify_service_without_siret).with(administrateur_with_siret_service.email)
    end
  end
end
