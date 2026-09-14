# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260731cleanServiceSiretTask do
    describe '#collection' do
      let!(:service_to_clean) { create(:service, siret: '35600082800018') }
      let!(:service_with_other_siret) { create(:service, siret: '13002526500013') }

      it 'returns services with the old test SIRET' do
        expect(described_class.new.collection).to contain_exactly(service_to_clean)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(service) }

      let(:service) { create(:service, siret: '35600082800018') }

      context 'when the service has a published procedure' do
        let!(:procedure) { create(:procedure, :published, service:) }

        it 'sets the SIRET to nil' do
          subject

          expect(service.reload.siret).to be_nil
        end
      end

      context 'when the service has a closed procedure' do
        let!(:procedure) { create(:procedure, :closed, service:) }

        it 'sets the SIRET to nil' do
          subject

          expect(service.reload.siret).to be_nil
        end
      end

      context 'when the service only has draft procedures' do
        let!(:procedure) { create(:procedure, :draft, service:) }

        it 'sets the SIRET to the test SIRET' do
          subject

          expect(service.reload.siret).to eq(Service::SIRET_TEST)
        end
      end

      context 'when the service has a published procedure and a draft procedure' do
        let!(:procedure_published) { create(:procedure, :published, service:) }
        let!(:procedure_draft) { create(:procedure, :draft, service:) }

        it 'sets the SIRET to nil' do
          subject

          expect(service.reload.siret).to be_nil
        end
      end
    end
  end
end
