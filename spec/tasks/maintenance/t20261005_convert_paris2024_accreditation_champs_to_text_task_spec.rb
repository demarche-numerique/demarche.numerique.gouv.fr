# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261005ConvertParis2024AccreditationChampsToTextTask do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :cojo }]) }
    let(:type_de_champ) { procedure.published_revision.type_de_champs.first }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:accreditation_success) { true }

    before do
      champ.update_columns(
        value: nil,
        external_id: { accreditation_number: '123456', accreditation_birthdate: '1959-12-21' },
        external_state: 'fetched',
        data: { accreditation_success:, accreditation_first_name: 'Florence', accreditation_last_name: 'Griffith-Joyner' }
      )
    end

    describe "#collection" do
      it "returns the ids of the cojo types de champ" do
        expect(described_class.new.collection).to contain_exactly([type_de_champ.id, type_de_champ.stable_id])
      end
    end

    describe "#process" do
      subject(:process) { described_class.process([type_de_champ.id, type_de_champ.stable_id]) }

      it "converts the type de champ to text" do
        expect { process }.to change { TypeDeChamp.find(type_de_champ.id).type_champ }.from('cojo').to('text')
      end

      it "converts the champ to text, keeping what the instructeur saw as value" do
        process

        converted = Champs::TextChamp.find(champ.id)
        expect(converted.value).to eq('N° d’accréditation : 123456, date de naissance : 21/12/1959, nom dans la base d’accréditation : Griffith-Joyner Florence')
        expect(converted.data).to be_nil
        expect(converted.external_id).to be_nil
        expect(converted.external_state).to eq('idle')
      end

      context "when the accreditation was not found" do
        let(:accreditation_success) { false }

        it "says so in the value" do
          process

          expect(Champs::TextChamp.find(champ.id).value).to eq('N° d’accréditation : 123456, date de naissance : 21/12/1959, accréditation non trouvée')
        end
      end

      it "leaves value nil when nothing was filled" do
        champ.update_columns(external_id: nil, external_state: nil, data: nil)

        process

        expect(Champs::TextChamp.find(champ.id).value).to be_nil
      end
    end
  end
end
