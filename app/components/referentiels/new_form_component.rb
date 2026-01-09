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
    if @referentiel.persisted? && @referentiel.valid?
      admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel)
    else
      admin_procedure_referentiels_path(@procedure, @type_de_champ.stable_id)
    end
  end

  def form_options
    {
      data: { turbo: 'true', controller: 'referentiel-new-form' },
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

  def submit_options
    if referentiel.type.nil?
      { class: 'fr-btn', disabled: true }
    else
      { class: 'fr-btn' }
    end
  end
end
