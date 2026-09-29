# frozen_string_literal: true

class ProConnectAdministrateurAnnouncementComponent < ApplicationComponent
  PRO_CONNECT_URL = "https://www.proconnect.gouv.fr/"

  private

  def pro_connect_link
    link_to "ProConnect", PRO_CONNECT_URL, **helpers.external_link_attributes("ProConnect")
  end
end
