# frozen_string_literal: true

class TypesDeChamp::ReferentielTypeDeChamp < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE
  def self.option_keys = [:referentiel_mapping]

  store_accessor :options, :referentiel_mapping

  def prefillable? = referentiel_in_exact_match?

  def referentiel_in_exact_match? = referentiel.present? && referentiel.exact_match?

  # Un référentiel partagé avec un champ d'une autre révision est dupliqué avant
  # d'être modifié : les dossiers de cette révision gardent le leur.
  def ensure_exclusive_referentiel!
    return referentiel if !referentiel.type_de_champs.where.not(id:).exists?

    # Copie conforme d'une ligne déjà en base : ne pas la valider, sinon une ligne
    # devenue invalide (URL retirée de la liste blanche, données de test manquantes)
    # ne serait pas sauvée et l'autosave du belongs_to poserait referentiel_id à nil.
    # Le formulaire valide l'écriture qui suit.
    transaction do
      copy = referentiel.dup
      copy.save!(validate: false)
      update!(referentiel: copy)
      copy
    end
  end

  def revision_diff_options
    {
      referentiel_url_tiptap: RevisionDiffValue.new(referentiel&.url_tiptap) { referentiel_url_as_text },
      referentiel_mode: referentiel&.mode,
      referentiel_hint: referentiel&.hint,
      referentiel_test_data_tiptap: RevisionDiffValue.new(referentiel&.test_data_tiptap) { referentiel&.test_data_tiptap&.values&.join(', ') },
      referentiel_mapping:,
    }
  end

  # The URL is a tiptap document whose mentions stand for query parameters.
  def referentiel_url_as_text
    return if referentiel&.url_tiptap.blank?

    # mentions carry the libellé of the champ they stand for: render them as
    # « {libellé} » rather than their stable_id, which means nothing to an admin
    url_tiptap = referentiel.url_tiptap.deep_symbolize_keys
    substitutions = TiptapService.used_tags_and_libelle_for(url_tiptap).to_h { |id, label| [id, "{#{label}}"] }
    TiptapService.new.to_texts_and_tags(url_tiptap, substitutions)
  end

  def safe_referentiel_mapping
    Hash(referentiel_mapping).with_indifferent_access
  end

  # Le préfixe commun des chemins mappés : c'est là que la réponse doit porter une valeur
  # pour que la référence compte comme trouvée. Sans mapping, la racine suffit.
  def referentiel_mapping_result_path
    JSONPathUtil.common_prefix(safe_referentiel_mapping.keys).presence || '$'
  end

  def referentiel_mapping_prefillable
    safe_referentiel_mapping.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill] == "1" }
  end

  def referentiel_mapping_prefillable_with_stable_id
    referentiel_mapping_prefillable.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill_stable_id].present? }
  end

  def referentiel_mapping_prefillable_stable_ids
    referentiel_mapping_prefillable_with_stable_id.map { |_jsonpath, mapping_opts| mapping_opts[:prefill_stable_id] }
  end

  def referentiel_mapping_displayable
    safe_referentiel_mapping.filter { |_jsonpath, mapping_opts| mapping_opts[:prefill] != "1" }
  end

  def referentiel_mapping_displayable_for_instructeur
    referentiel_mapping_displayable.filter { |_jsonpath, mapping| mapping[:display_instructeur] == "1" }
  end

  def referentiel_mapping_displayable_for_usager
    referentiel_mapping_displayable.filter { |_jsonpath, mapping| mapping[:display_usager] == "1" }
  end
end
