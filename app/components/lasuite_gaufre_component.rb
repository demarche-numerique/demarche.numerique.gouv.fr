# frozen_string_literal: true

# Loads the La Suite "gaufre" v2 widget and binds it to the header trigger
# button. The trigger buttons themselves are rendered in the header (see
# layouts/_lasuite_gaufre_button); this component only loads the widget script,
# initializes it (labels translated via i18n) and themes its panel for dark mode.
class LasuiteGaufreComponent < ApplicationComponent
  WIDGET_SCRIPT_URL = "https://integration.lasuite.numerique.gouv.fr/widgets/dist/lagaufre.js"
  SERVICES_API_URL = "https://lasuite.numerique.gouv.fr/api/services"

  # Ids of the trigger buttons rendered in the header (mobile + desktop).
  BUTTON_IDS = ["lasuite-gaufre-mobile", "lasuite-gaufre-desktop"].freeze

  def render?
    helpers.administrateur_signed_in? || helpers.instructeur_signed_in?
  end

  # Widget init options whose values are localized strings.
  def widget_config
    {
      api: SERVICES_API_URL,
      # Shared with the trigger button's aria-label, so it lives in a global key.
      label: t("lasuite_gaufre.label"),
      closeLabel: t(".close_label"),
      headerLabel: t(".header_label"),
      loadingText: t(".loading_text"),
      newWindowLabelSuffix: t(".new_window_suffix"),
      viewMoreLabel: t(".view_more_label"),
      viewLessLabel: t(".view_less_label"),
    }
  end
end
