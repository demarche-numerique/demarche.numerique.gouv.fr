# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261113CreateEaeIntegrationProcedureTask do
    describe "#process" do
      let(:administrateur) { administrateurs.blank }
      let(:task) { described_class.new.tap { it.administrateur_email = " #{administrateur.email.upcase} " } }

      it "creates the draft procedure for the administrateur found by e-mail" do
        expect(task.collection).to eq([administrateur])

        expect { task.process(administrateur) }.to change { administrateur.procedures.count }.by(1)

        expect(administrateur.procedures.last).to have_attributes(
          libelle: ProcedureTemplates::EaeIntegration::TITLE, aasm_state: "brouillon", auto_archive_on: nil
        )
      end

      it "gives the procedure the deadline it is given" do
        task.deadline = (Date.current.next_occurring(:wednesday) + 4.weeks).iso8601

        task.process(administrateur)

        expect(administrateur.procedures.last.auto_archive_on).to eq(task.deadline + 1.day)
      end
    end
  end
end
