# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe BackfillChampsNewIdTask do
    # ignored_columns keeps new_id off the instance, so it can only be read back
    # in SQL; and the trigger fills it on insert, so the setup has to undo that.
    def new_id_of(champ) = ChampData.connection.select_value("SELECT new_id FROM champs WHERE id = #{champ.id}")

    def blank_out_new_id(champ)
      ChampData.connection.exec_update("UPDATE champs SET new_id = NULL WHERE id = #{champ.id}")
    end

    let(:dossier) { dossiers.en_construction }
    let(:champ) { dossier.champ_data.first }

    describe "#process" do
      subject(:process) { described_class.process(ChampData.where(id: champ.id)) }

      it "fills a row the trigger did not reach" do
        blank_out_new_id(champ)

        expect { process }.to change { new_id_of(champ) }.from(nil).to(champ.id)
      end

      it "leaves an already filled row untouched" do
        expect { process }.not_to change { new_id_of(champ) }.from(champ.id)
      end
    end

    describe "#collection" do
      it "enumerates primary-key batches without filtering (the filter lives in each batch's UPDATE)" do
        expect(described_class.new.collection).to be_a(ActiveRecord::Batches::BatchEnumerator)
      end
    end
  end
end
