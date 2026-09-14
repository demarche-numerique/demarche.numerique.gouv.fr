# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260914scheduleCronJobsTask do
    describe "#process" do
      subject(:process) { described_class.process }

      after { Sidekiq::Cron::Job.destroy_all! }

      it "registers a schedulable cron job in Redis" do
        process

        expect(Sidekiq::Cron::Job.find(Cron::ExpiredDossiersBrouillonDeletionJob.name)).to be_present
      end

      context "when a schedule remains for a class that is no longer schedulable" do
        let(:orphan_class) { 'Cron::ThisJobNoLongerExistsJob' }

        before { Sidekiq::Cron::Job.create(name: orphan_class, cron: '0 0 * * *', class: orphan_class) }

        it "prunes it" do
          expect { process }.to change { Sidekiq::Cron::Job.find(orphan_class) }.to(nil)
        end
      end
    end
  end
end
