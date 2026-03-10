# frozen_string_literal: true

module MailerHelper
  def vertical_margin(height)
    render 'layouts/mailers/vertical_margin', height: height
  end

  def dsfr_button(text, url, variant)
    render 'layouts/mailers/dsfr_button', text: text, url: url, variant: variant
  end

  def application_name_without_link
    # The WORD JOINER unicode entity (&#8288;) prevents email clients from auto-linking the app name
    APPLICATION_NAME.gsub(".", "&#8288;.").html_safe # rubocop:disable Rails/OutputSafety
  end
end
