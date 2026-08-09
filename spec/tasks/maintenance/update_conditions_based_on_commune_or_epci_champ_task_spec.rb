# frozen_string_literal: true

require "rails_helper"

module Maintenance
  describe UpdateConditionsBasedOnCommuneOrEpciChampTask do
    include Logic
    describe "#process" do
      subject(:process) { described_class.process(revision) }

      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :communes }, { type: :epci }, { type: :drop_down_list, libelle: 'Votre choix', options: ['Choix 1', 'Choix 2', 'Choix 3'] }, { type: :text }]) }
      let(:revision) { procedure.active_revision }

      let(:text_tdc) { revision.root_types_de_champ_public.find(&:text?) }
      let(:commune_tdc) { revision.root_types_de_champ_public.find(&:communes?) }
      let(:epci_tdc) { revision.root_types_de_champ_public.find(&:epci?) }
      let(:drop_down_list_tdc) { revision.root_types_de_champ_public.find(&:drop_down_list?) }

      context "with a condition based on commune and epci" do
        before { text_tdc.record.update(condition: ds_and([ds_eq(champ_value(commune_tdc.stable_id), constant('11')), ds_not_eq(champ_value(epci_tdc.stable_id), constant('84'))])) }

        it "updates condition" do
          expect(text_tdc.condition).to eq ds_and([ds_eq(champ_value(commune_tdc.stable_id), constant('11')), ds_not_eq(champ_value(epci_tdc.stable_id), constant('84'))])

          subject

          text_tdc.reload

          expect(text_tdc.condition).to eq ds_and([ds_in_departement(champ_value(commune_tdc.stable_id), constant('11')), ds_not_in_departement(champ_value(epci_tdc.stable_id), constant('84'))])
        end
      end

      context "with a condition based on a dropdown list" do
        before { text_tdc.record.update(condition: ds_eq(champ_value(drop_down_list_tdc.stable_id), constant('Choix 2'))) }

        it "does not update condition" do
          expect(text_tdc.condition).to eq ds_eq(champ_value(drop_down_list_tdc.stable_id), constant('Choix 2'))

          subject

          text_tdc.reload

          expect(text_tdc.condition).to eq ds_eq(champ_value(drop_down_list_tdc.stable_id), constant('Choix 2'))
        end
      end
    end
  end
end
