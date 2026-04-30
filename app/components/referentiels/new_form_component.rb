# frozen_string_literal: true

class Referentiels::NewFormComponent < Referentiels::MappingFormBase
  delegate :authentication_by_header_token?,
           :authentication_data_header,
           to: :referentiel

  def id
    :new_referentiel
  end

  def back_url
    champs_admin_procedure_path(@procedure)
  end

  def form_url
    if @referentiel.persisted?
      admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel)
    else
      admin_procedure_referentiels_path(@procedure, @type_de_champ.stable_id)
    end
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
    validate_url_admin_procedure_referentiels_path(@procedure, @type_de_champ.stable_id)
  end

  def submit_options
    if referentiel.type.nil?
      { class: 'fr-btn', disabled: true }
    else
      { class: 'fr-btn' }
    end
  end

  def coordinate
    @coordinate ||= @procedure.draft_revision.coordinate_for(@type_de_champ)
  end

  def tags
    eligible_types = %w[text email phone number integer_number decimal_number formatted iban siret drop_down_list dossier_link rna rnf annuaire_education]

    field_tags = coordinate.upper_coordinates
      .filter { eligible_types.include?(_1.type_champ) }
      .map { |coord| { id: "tdc#{coord.stable_id}", libelle: coord.libelle } }

    query_tag = { id: "{query}", libelle: "Valeur saisie par l’usager", highlight: true }

    { url_tags: [query_tag] + field_tags }
  end

  delegate :test_data_tags, to: :referentiel
end
