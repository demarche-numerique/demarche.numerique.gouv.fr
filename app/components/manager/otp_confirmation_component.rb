# frozen_string_literal: true

class Manager::OtpConfirmationComponent < ApplicationComponent
  def initialize(title:, url:, submit:, cancel_url:, form_method: :post)
    @title = title
    @url = url
    @submit = submit
    @cancel_url = cancel_url
    @form_method = form_method
  end

  attr_reader :title, :url, :submit, :cancel_url, :form_method
end
