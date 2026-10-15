# frozen_string_literal: true

class EditableChamp::CarteComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper
  def dsfr_champ_container
    :fieldset
  end

  def react_props
    {
      feature_collection: @champ.to_feature_collection,
      champ_id: @champ.focusable_input_id,
      url: update_path,
      adresse_source: data_sources_data_source_adresse_path,
      options: @champ.render_options,
      translations: {
        address_input_label: t(".address_input_label"),
        address_input_description: t(".address_input_description"),
        address_placeholder: t(".address_placeholder"),
        address_search_error: t(".address_search_error"),
        pin_input_label: t(".pin_input_label"),
        pin_input_description: t(".pin_input_description"),
        show_pin: t(".show_pin"),
        add_pin: t(".add_pin"),
        add_file: t(".add_file"),
        choose_file: t(".choose_file"),
        delete_file: t(".delete_file"),
      },
      ariaLabelledbyPrefix: "#{aria_labelledby_prefix} #{champ_fieldset_legend_id(@champ)}",
    }
  end

  def update_path
    champs_carte_features_path(@champ.dossier, @champ.public_id)
  end
end
