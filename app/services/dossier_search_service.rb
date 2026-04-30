# frozen_string_literal: true

class DossierSearchService
  def self.matching_dossiers(dossiers, search_terms, with_annotations = false)
    if dossiers.nil?
      []
    else
      dossier_by_exact_id(dossiers, search_terms)
        .presence || dossier_ids_by_full_text(dossiers, search_terms, with_annotations)
    end
  end

  def self.matching_dossiers_for_user(search_terms, user)
    dossier_by_exact_id_for_user(search_terms, user)
      .presence || dossier_by_full_text_for_user(search_terms, Dossier.includes(:procedure).where(id: user.dossiers.ids + user.dossiers_invites.ids))
  end

  private

  def self.dossier_by_exact_id(dossiers, search_terms)
    id = search_terms.to_i
    if id != 0 && id_compatible?(id) # Sometimes instructeur is searching dossiers with a big number (ex: SIRET), ActiveRecord can't deal with them and throws ActiveModel::RangeError. id_compatible? prevents this.
      dossiers.visible_by_administration.where(id: id).ids
    else
      []
    end
  end

  def self.dossier_ids_by_full_text(dossiers, search_terms, with_annotations)
    dossier_by_full_text(dossiers.visible_by_administration, search_terms, with_annotations:)
      .pluck('id')
      .uniq
  end

  def self.dossier_by_full_text_for_user(search_terms, dossiers)
    dossier_by_full_text(dossiers.visible_by_user, search_terms)
  end

  def self.dossier_by_full_text(dossiers, search_terms, with_annotations: false)
    columns = with_annotations ? 'search_terms || \' \' || private_search_terms' : 'search_terms'

    ts_vector = "to_tsvector('french_unaccent', #{columns})"
    ts_query = "to_tsquery('french_unaccent', #{Dossier.connection.quote(to_tsquery(search_terms))})"

    dossiers
      .where("#{ts_vector} @@ #{ts_query}")
      .order(Arel.sql("COALESCE(ts_rank(#{ts_vector}, #{ts_query}), 0) DESC"))
  end

  def self.dossier_by_exact_id_for_user(search_terms, user)
    id = search_terms.to_i
    if id != 0 && id_compatible?(id) # Sometimes user is searching dossiers with a big number (ex: SIRET), ActiveRecord can't deal with them and throws ActiveModel::RangeError. id_compatible? prevents this.
      Dossier.includes(:procedure).where(id: user.dossiers.visible_by_user.where(id: id) + user.dossiers_invites.visible_by_user.where(id: id)).distinct
    else
      Dossier.includes(:procedure).none
    end
  end

  def self.id_compatible?(number)
    ActiveRecord::Type::Integer.new.serialize(number).present?
  rescue ActiveModel::RangeError
    false
  end

  def self.to_tsquery(search_terms)
    (search_terms || "")
      .gsub(/['?\\:&|!<>()]/, "") # drop disallowed characters
      .strip
      .split(/\s+/)           # split words
      .map { |x| "#{x}:*" }   # enable prefix matching
      .join(" & ")
  end
end
