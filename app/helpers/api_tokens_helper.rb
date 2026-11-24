# frozen_string_literal: true

module APITokensHelper
  def api_token_form_title(form)
    if form.copying?
      t('administrateurs.api_tokens.copy_title')
    elsif form.duplicating?
      t('administrateurs.api_tokens.duplicate_title')
    else
      t('administrateurs.api_tokens.new_token')
    end
  end
end
