# frozen_string_literal: true

RSpec.describe DossierIndexSearchTermsJob, type: :job do
  let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }
  let(:public_type_de_champs) { [{ type: :text }] }
  let(:private_type_de_champs) { [{ type: :text }] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ_siret) { dossier.champ_data.first }

  subject(:perform_job) { described_class.perform_now(dossier.reload) }

  before do
    dossier.public_root_champs.first.update_column(:value, "un nouveau champ")
    dossier.private_root_champs.first.update_column(:value, "private champ")
  end

  it "update search terms columns" do
    perform_job

    sql = "SELECT search_terms_tsvector @@ to_tsquery('french_unaccent', 'nouveau & champ') AS public_match, all_search_terms_tsvector @@ to_tsquery('french_unaccent', 'private') AS private_match FROM dossiers WHERE id = :id"
    sanitized_sql = Dossier.sanitize_sql_array([sql, id: dossier.id])
    result = Dossier.connection.execute(sanitized_sql).first

    expect(result['public_match']).to be(true)
    expect(result['private_match']).to be(true)
  end
end
