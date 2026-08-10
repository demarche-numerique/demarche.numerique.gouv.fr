# frozen_string_literal: true

module DossierSearchableConcern
  extend ActiveSupport::Concern

  SEARCH_TERMS_DEBOUNCE = 5.minutes
  SEARCH_TERMS_DEBOUNCE_LIGHT_USER = 1.hour
  LIGHT_USER_DOSSIERS_THRESHOLD = 5

  included do
    after_commit :index_search_terms_later, on: [:create, :update], if: -> { previously_new_record? || user_previously_changed? || mandataire_first_name_previously_changed? || mandataire_last_name_previously_changed? }

    kredis_flag :debounce_index_search_terms_flag
  end

  def index_search_terms
    DossierPreloader.load_one(self)

    search_terms = [
      user&.email,
      *root_public_champs.flat_map(&:search_terms),
      *etablissement&.search_terms,
      individual&.nom,
      individual&.prenom,
      mandataire_first_name,
      mandataire_last_name,
    ].compact_blank.join(' ')

    private_search_terms = root_private_champs.flat_map(&:search_terms).compact_blank.join(' ')

    # Mirrors the `search_terms || ' ' || private_search_terms` expression the
    # annotations index is built on: `to_tsquery` ANDs its terms, so a query
    # spanning the public and private parts must see them as one document.
    all_search_terms = "#{search_terms} #{private_search_terms}"

    sql = <<~SQL.squish
      UPDATE dossiers SET
        search_terms = :search_terms,
        private_search_terms = :private_search_terms,
        search_terms_tsvector = to_tsvector('french_unaccent', :search_terms),
        all_search_terms_tsvector = to_tsvector('french_unaccent', :all_search_terms)
      WHERE id = :id
    SQL
    sanitized_sql = self.class.sanitize_sql_array([sql, search_terms:, private_search_terms:, all_search_terms:, id:])
    self.class.connection.execute(sanitized_sql)
  end

  def index_search_terms_later
    return if debounce_index_search_terms_flag.marked?

    wait = light_user_brouillon? ? SEARCH_TERMS_DEBOUNCE_LIGHT_USER : SEARCH_TERMS_DEBOUNCE
    debounce_index_search_terms_flag.mark(expires_in: wait)
    DossierIndexSearchTermsJob.set(wait:).perform_later(self)
  end

  private

  def light_user_brouillon?
    brouillon? && user && user.dossiers.count <= LIGHT_USER_DOSSIERS_THRESHOLD
  end
end
