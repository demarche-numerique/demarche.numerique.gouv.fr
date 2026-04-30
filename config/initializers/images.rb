# frozen_string_literal: true

# Favicons
FAVICONS_SRC = {
  "16px" => ENV.fetch("FAVICON_16PX_SRC", "favicons/16x16.png"),
  "32px" => ENV.fetch("FAVICON_32PX_SRC", "favicons/32x32.png"),
  "96px" => ENV.fetch("FAVICON_96PX_SRC", "favicons/96x96.png"),
  "apple_touch" => ENV.fetch("FAVICON_APPLE_TOUCH_152PX_SRC", "favicons/apple-touch-icon.png"),
}.compact_blank.freeze

# Header logo
HEADER_LOGO_SRC = ENV.fetch("HEADER_LOGO_SRC", "marianne.png")
HEADER_LOGO_ALT = ENV.fetch("HEADER_LOGO_ALT", "Liberté, égalité, fraternité")
HEADER_LOGO_WIDTH = ENV.fetch("HEADER_LOGO_WIDTH", "65")
HEADER_LOGO_HEIGHT = ENV.fetch("HEADER_LOGO_HEIGHT", "56")

# Institution logo and Marianne logo, used in emails and PDF documents (attestations, etc.).
# Set LOGO_MARIANNE_SRC to an empty value to hide the Marianne logo entirely.
# DIRECTION_LABEL is displayed next to APPLICATION_NAME in document headers (e.g. "Direction Interministérielle du Numérique").
# For deeper customization, you can override the email layout partials:
# app/views/layouts/mailers/_dsfr_header.html.erb, _dsfr_identity.html.erb, _dsfr_footer.html.erb
# See https://github.com/demarche-numerique/demarche.numerique.gouv.fr/blob/main/doc/customization.md
LOGO_SRC = ENV.fetch("LOGO_SRC", "logo-demarche-numerique@2x.png")
LOGO_MARIANNE_SRC = ENV.fetch("LOGO_MARIANNE_SRC", "Marianne-Light@2x.png")
LOGO_DARK_SRC = ENV.fetch("LOGO_DARK_SRC", "logo-demarche-numerique@2x.png")
LOGO_MARIANNE_DARK_SRC = ENV.fetch("LOGO_MARIANNE_DARK_SRC", "Marianne-Dark@2x.png")
DIRECTION_LABEL = ENV.fetch("DIRECTION_LABEL", "")

# Default logo of a procedure
PROCEDURE_DEFAULT_LOGO_SRC = ENV.fetch("PROCEDURE_DEFAULT_LOGO_SRC", "republique-francaise-logo.svg")

# Logo in PDF export of a "Dossier"
DOSSIER_PDF_EXPORT_LOGO_SRC = Rails.root.join(ENV.fetch("DOSSIER_PDF_EXPORT_LOGO_SRC", "app/assets/images/header/logo-ds-wide.png")).to_s
