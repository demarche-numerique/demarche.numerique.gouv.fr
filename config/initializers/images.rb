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

# Two logos can be shown in the email header, each with a light and dark variant:
# - Marianne logo (left). Set to an empty value to hide it entirely.
# - Application/instance logo (right of Marianne, or alone if Marianne is hidden). Mandatory.
# For deeper customization, you can override the email layout partials:
# app/views/layouts/mailers/_dsfr_header.html.erb, _dsfr_identity.html.erb, _dsfr_footer.html.erb
# See https://github.com/demarche-numerique/demarche.numerique.gouv.fr/blob/main/doc/customization.md
MAILER_LOGO_MARIANNE_SRC = ENV.fetch("MAILER_LOGO_MARIANNE_SRC", "mailer/Marianne-Light@2x.png")
MAILER_LOGO_MARIANNE_DARK_SRC = ENV.fetch("MAILER_LOGO_MARIANNE_DARK_SRC", "mailer/Marianne-Dark@2x.png")
MAILER_LOGO_SRC = ENV.fetch("MAILER_LOGO_SRC", "mailer/logo-demarche-numerique@2x.png")
MAILER_LOGO_DARK_SRC = ENV.fetch("MAILER_LOGO_DARK_SRC", "mailer/logo-demarche-numerique@2x.png")

# Default logo of a procedure
PROCEDURE_DEFAULT_LOGO_SRC = ENV.fetch("PROCEDURE_DEFAULT_LOGO_SRC", "republique-francaise-logo.svg")

# Logo in PDF export of a "Dossier"
DOSSIER_PDF_EXPORT_LOGO_SRC = Rails.root.join(ENV.fetch("DOSSIER_PDF_EXPORT_LOGO_SRC", "app/assets/images/header/logo-ds-wide.png")).to_s
