# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261007EnablePrefillIbanTask do
    let_it_be(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :iban }]) }

    def iban_champ_on(procedure, prefilled:, dossier_prefilled: prefilled)
      dossier = create(:dossier, procedure:, prefilled: dossier_prefilled)
      dossier.root_champs_public.first.tap { it.update!(value: 'FR7630006000011234567890189', prefilled:) }
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      let(:typed_by_usager) { create(:procedure, :published, public_type_de_champs: [{ type: :iban }]) }
      let(:filled_by_referentiel) { create(:procedure, :published, public_type_de_champs: [{ type: :iban }]) }

      before do
        iban_champ_on(procedure, prefilled: true)
        iban_champ_on(typed_by_usager, prefilled: false, dossier_prefilled: true)
        iban_champ_on(filled_by_referentiel, prefilled: true, dossier_prefilled: false)
      end

      it "returns the procedures whose IBAN came from a prefill link or request" do
        expect(collection).to include(procedure)
        expect(collection).not_to include(typed_by_usager, filled_by_referentiel)
      end
    end

    describe "#process" do
      it "enables the IBAN prefill on the procedure" do
        described_class.process(procedure)

        expect(Flipper.enabled?(:prefill_iban, procedure)).to be(true)
      end
    end
  end
end
