# frozen_string_literal: true

class APIEntreprise::PrivilegesAdapter < APIEntreprise::Adapter
  def initialize(token)
    @token = token
  end

  def scopes
    payload = JWT.decode(@token&.jwt_token, nil, false).first || {}
    Array(payload.with_indifferent_access["scopes"])
  rescue JWT::DecodeError, NoMethodError
    []
  end

  def valid?
    begin
      get_resource
      true
    rescue
      false
    end
  end

  private

  def get_resource
    api.tap do
      _1.token = @token
    end.privileges
  end
end
