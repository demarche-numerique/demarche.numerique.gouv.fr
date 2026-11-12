# frozen_string_literal: true

class Referentiels::NewFormComponent < Referentiels::MappingFormBase
  delegate :authentication_by_header_token?,
           :authentication_data_header,
           :test_data_tags,
           to: :referentiel

  def id
    :new_referentiel
  end

  def form_url
    admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id)
  end

  def form_options
    {
      data: { turbo: 'true', controller: 'referentiel-new-form autosubmit-validate-url', 'autosubmit-validate-url-url-value': validate_url_path },
      html: { novalidate: 'novalidate', id: },
    }
  end

  def authentication_data_header_opts
    options = {
      opts: {
        name: "referentiel[authentication_data][header]",
        value: authentication_data_header,
        data: {
          'referentiel-new-form-target' => 'header',
        },
      },
    }

    options[:opts][:disabled] = true if authentication_by_header_token?
    options
  end

  def authentication_data_header_value_opts
    options = {
      opts: {
        name: "referentiel[authentication_data][value]",
        input_type: authentication_by_header_token? ? :password : :text,
        value: authentication_by_header_token? ? "C’est un secret" : '',
        data: {
          'referentiel-new-form-target' => 'value',
        },
      },
    }
    options[:opts][:disabled] = true if authentication_by_header_token?
    options
  end

  def validate_url_path
    validate_url_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id)
  end

  def submit_options
    if referentiel.type.nil?
      { class: 'fr-btn', disabled: true }
    else
      { class: 'fr-btn' }
    end
  end

  def tags
    eligible_types = %w[text email phone number integer_number decimal_number formatted iban siret drop_down_list dossier_link rna rnf annuaire_education yes_no checkbox address]

    field_tags = @type_de_champ.upper_type_de_champs
      .filter { eligible_types.include?(it.type_champ) }
      .map { { id: "tdc#{it.stable_id}", libelle: it.libelle } }

    query_tag = { id: ReferentielService::USAGER_INPUT_TAG, libelle: "Valeur saisie par l’usager", highlight: true }
    dossier_number_tag = { id: ReferentielService::DOSSIER_NUMBER_TAG, libelle: "Numéro du dossier", highlight: true }

    { url_tags: [query_tag, dossier_number_tag] + field_tags }
  end
end
