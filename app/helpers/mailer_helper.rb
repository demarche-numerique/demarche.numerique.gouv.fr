# frozen_string_literal: true

module MailerHelper
  def vertical_margin(height)
    render 'shared/mailer_vertical_margin', height: height
  end

  def round_button(text, url, variant)
    render 'shared/mailer_round_button', text: text, url: url, theme: theme(variant)
  end

  def dsfr_button(text, url, variant)
    render 'shared/mailer_dsfr_button', text: text, url: url, variant: variant
  end

  def application_name_without_link
    # The WORD JOINER unicode entity (&#8288;) prevents email clients from auto-linking the app name
    APPLICATION_NAME.gsub(".", "&#8288;.").html_safe # rubocop:disable Rails/OutputSafety
  end

  private

  def theme(variant)
    case variant
    when :primary
      { color: white, bg_color: blue, border_color: blue }
    when :secondary
      { color: blue, bg_color: white, border_color: blue }
    end
  end

  def blue
    '#000091'
  end

  def white
    '#FFFFFF'
  end
end
