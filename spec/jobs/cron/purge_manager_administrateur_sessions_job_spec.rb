# frozen_string_literal: true

RSpec.describe Cron::PurgeManagerAdministrateurSessionsJob, type: :job do
  describe 'perform' do
    let(:administrateur) { create(:administrateur) }
    let(:procedure) { create(:procedure) }

    subject { Cron::PurgeManagerAdministrateurSessionsJob.perform_now }

    context "with an inactive administrateur" do
      before do
        AdministrateursProcedure.create(procedure: procedure, administrateur: administrateur, manager: true)
      end

      it {
        expect(AdministrateursProcedure.where(procedure:, manager: true).count).to eq(1)
        expect(AdministrateursProcedure.where(procedure:).count).to eq(2)
        subject
        expect(AdministrateursProcedure.where(procedure:, manager: true).count).to eq(0)
        expect(AdministrateursProcedure.where(procedure:).count).to eq(1)
      }
    end

    context "with a list token of the manager administrateur" do
      let(:api_token) { APIToken.generate(administrateur).first }

      before do
        AdministrateursProcedure.create(procedure:, administrateur:, manager: true)
        api_token.update!(allowed_procedure_ids: [procedure.id, procedures.brouillon.id])
      end

      it "drops the procedure from the token" do
        subject
        expect(api_token.reload.allowed_procedure_ids).to eq([procedures.brouillon.id])
      end
    end
  end
end
