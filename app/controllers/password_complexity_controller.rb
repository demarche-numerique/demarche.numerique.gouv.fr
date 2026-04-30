# frozen_string_literal: true

class PasswordComplexityController < ApplicationController
  def show
    # Bound the input to Devise's max length to prevent abusing zxcvbn's
    # super-linear scoring on arbitrarily large strings.
    password = password_param.to_s.first(Devise.password_length.max)
    @length = password.length
    @score = ZxcvbnService.complexity(password)
    @min_length = PASSWORD_MIN_LENGTH
    @min_complexity = PASSWORD_COMPLEXITY_FOR_ADMIN
  end

  private

  def password_param
    params
      .transform_keys! { |k| params[k].try(:has_key?, :password) ? 'resource' : k }
      .dig(:resource, :password)
  end
end
