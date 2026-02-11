# frozen_string_literal: true

RSpec.configure do |config|
  config.include Warden::Test::Helpers

  config.before(:suite) do
    Warden.test_mode!
  end
end
