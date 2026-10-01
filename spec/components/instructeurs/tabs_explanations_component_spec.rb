# frozen_string_literal: true

require "rails_helper"

RSpec.describe Instructeurs::TabsExplanationsComponent, type: :component do
  let(:modal_html) { rendered_content }

  %w[index show].each do |action|
    context "on the #{action} page" do
      before do
        allow_any_instance_of(described_class).to receive(:action_name).and_return(action)
        render_inline(described_class.new)
      end

      it_behaves_like 'a labelled DSFR modal', 'modal-tabs-explanations'
    end
  end
end
