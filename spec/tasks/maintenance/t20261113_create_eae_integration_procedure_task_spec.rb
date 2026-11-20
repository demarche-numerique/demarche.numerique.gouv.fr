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

        expect(administrateur.procedures.last).to have_attributes(libelle: ProcedureTemplates::EaeIntegration::LIBELLE, aasm_state: "brouillon")
      end
    end
  end
end
