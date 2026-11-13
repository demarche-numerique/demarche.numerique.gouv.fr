# frozen_string_literal: true

require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true, net_http_connect_on_start: %w[localhost 127.0.0.1])
