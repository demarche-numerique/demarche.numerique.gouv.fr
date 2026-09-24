# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260728BackfillSearchTermsTsvectorTask do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
    let!(:dossier) do
      create(:dossier, procedure:, state: :en_construction).tap do |dossier|
        dossier.root_champs_public.first.update!(value: 'Hélène pommes')
      end
    end

    before do
      Dossier.where(id: dossier.id).update_all(search_terms_tsvector: nil, all_search_terms_tsvector: nil)
    end

    it "reindexes the dossiers without a stored tsvector from their champs" do
      expect(described_class.collection).to include(dossier)

      described_class.process(dossier)

      matching = Dossier.connection.select_value(
        Dossier.sanitize_sql_array(["SELECT search_terms_tsvector @@ to_tsquery('french_unaccent', 'helene') FROM dossiers WHERE id = :id", id: dossier.id])
      )
      expect(matching).to be(true)
      expect(described_class.collection).not_to include(dossier)
    end
  end
end
