# frozen_string_literal: true

class ProConnectInformation < ApplicationRecord
  self.table_name = 'agent_connect_informations'

  USER_INFO_KEYS = ['given_name', 'usual_name', 'email', 'sub', 'siret', 'organizational_unit', 'belonging_population', 'phone'].freeze

  belongs_to :user

  def self.record!(user:, auth:)
    find_or_initialize_by(user:, sub: auth.user_info['sub'])
      .update!(auth.user_info.slice(*USER_INFO_KEYS).merge(amr: auth.amr, acr: auth.acr))
  end

  def full_name
    "#{given_name} #{usual_name}".strip
  end
end
