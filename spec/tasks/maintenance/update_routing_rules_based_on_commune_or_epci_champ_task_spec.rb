# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe UpdateRoutingRulesBasedOnCommuneOrEpciChampTask do
    include Logic
    describe "#process" do
      subject(:process) { described_class.process(groupe_defaut) }

      let(:procedure) { create(:procedure, :published, :routee, types_de_champ_public: [{ type: :communes }, { type: :epci }, { type: :drop_down_list, libelle: 'Votre choix', options: ['Choix 1', 'Choix 2', 'Choix 3'] }, { type: :text }]) }

      let(:commune_tdc) { procedure.active_revision.root_public_types_de_champ.find(&:communes?) }
      let(:epci_tdc) { procedure.active_revision.root_public_types_de_champ.find(&:epci?) }
      let(:drop_down_list_tdc) { procedure.active_revision.root_public_types_de_champ.find(&:drop_down_list?) }

      let(:groupe_defaut) { procedure.defaut_groupe_instructeur }

      context "with a routing rule based on commune and epci" do
        before { groupe_defaut.update(routing_rule: ds_and([ds_eq(champ_value(commune_tdc.stable_id), constant('11')), ds_not_eq(champ_value(epci_tdc.stable_id), constant('84'))])) }

        it "updates routing rule" do
          subject
          expect(groupe_defaut.routing_rule).to eq ds_and([ds_in_departement(champ_value(commune_tdc.stable_id), constant('11')), ds_not_in_departement(champ_value(epci_tdc.stable_id), constant('84'))])
        end
      end

      context "with a routing rule based on a dropdown list" do
        before { groupe_defaut.update(routing_rule: ds_eq(champ_value(drop_down_list_tdc.stable_id), constant('Choix 2'))) }

        it "does not update routing rule" do
          subject
          expect(groupe_defaut.routing_rule).to eq ds_eq(champ_value(drop_down_list_tdc.stable_id), constant('Choix 2'))
        end
      end
    end
  end
end
