# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::UserFilterPanelComponent, type: :component do
  let(:procedures_for_select) { [] }
  let(:filter) do
    instance_double(Users::DossierFilterService,
      active?: false,
      total_count: 12,
      counts: {
        procedure_ids: {},
        states: { 'brouillon' => 1, 'en_construction' => 5, 'en_instruction' => 0, 'accepte' => 0, 'refuse' => 0, 'sans_suite' => 0 },
        alerts: { 'nouveau_message' => 0, 'message_avec_attente_de_reponse' => 3, 'a_corriger' => 0, 'expire_bientot' => 0 },
        shared_with_me: 0,
      })
  end
  let(:has_invites) { false }
  let(:filter_params) { {} }
  let(:render_content) { false }

  subject do
    render_inline(described_class.new(filter: filter, filter_params: filter_params, procedures_for_select: procedures_for_select, has_invites: has_invites, render_content: render_content))
  end

  describe 'lazy shell (render_content: false)' do
    # An unstubbed double: any method call (including counts) would raise,
    # proving the shell never computes the filter counts.
    let(:filter) { instance_double(Users::DossierFilterService) }

    it 'renders an empty turbo-frame that does not auto-load and does not compute counts' do
      frame = subject.css("turbo-frame#filter_panel")
      expect(frame).to be_present
      # No src and no loading=lazy: the frame loads on demand (JS sets src on drawer
      # open), never eagerly — otherwise the counts would run on every page load.
      expect(frame.attr('src')).to be_nil
      expect(frame.attr('loading')).to be_nil
    end

    it 'does not render the filter form' do
      expect(subject.css('input[name="state[]"]')).to be_empty
      expect(subject.css('input[type=submit]')).to be_empty
    end
  end

  describe 'rendered content (render_content: true)' do
    let(:render_content) { true }

    # The form itself is covered by Dossiers::UserFilterPanelFormComponent spec;
    # here we only assert the panel delegates to it inside the frame.
    it 'renders the filter form inside the frame' do
      expect(subject.css('turbo-frame#filter_panel form')).to be_present
      expect(subject.css('input[name="state[]"]')).to be_present
    end
  end
end
