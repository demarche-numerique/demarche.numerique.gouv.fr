# frozen_string_literal: true

require 'rails_helper'

# These endpoints only render turbo_stream: without a default format, a plain
# browser navigation (or a non-JS form submit) raises UnknownFormat (406).
RSpec.describe 'turbo_stream route defaults', type: :routing do
  {
    [:get, '/champs/1/12/carte/features'] => 'champs/carte#index',
    [:get, '/procedures/counters'] => 'instructeurs/procedures#counters',
    [:get, '/procedures/1/polling_last_export'] => 'instructeurs/procedures#polling_last_export',
    [:get, '/procedures/1/dossiers/1/annotations/12'] => 'instructeurs/dossiers#annotation',
    [:get, '/admin/procedures/1/check_path'] => 'administrateurs/procedures#check_path',
    [:post, '/admin/procedures/1/check_path'] => 'administrateurs/procedures#check_path',
    [:post, '/admin/procedures/1/dossier_submitted_message/preview'] => 'administrateurs/dossier_submitted_messages#preview',
  }.each do |(method, path), controller_action|
    it "defaults #{method.to_s.upcase} #{path} to turbo_stream" do
      controller, action = controller_action.split('#')
      params = Rails.application.routes.recognize_path(path, method:)
      expect(params).to include(controller:, action:, format: :turbo_stream)
    end
  end
end
