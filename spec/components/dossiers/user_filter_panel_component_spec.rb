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

  subject do
    render_inline(described_class.new(filter: filter, filter_params: filter_params, procedures_for_select: procedures_for_select, has_invites: has_invites))
  end

  it 'renders all 6 UI state checkboxes' do
    expect(subject.css('input[name="state[]"]').size).to eq(6)
  end

  it 'renders all 4 alert checkboxes' do
    expect(subject.css('input[name="alert[]"]').size).to eq(4)
  end

  it 'renders state counters inline' do
    expect(subject.to_html).to include('(5)') # en_construction count
    expect(subject.to_html).to include('(3)') # pending responses count
  end

  it 'does not render the procedure dropdown when no procedure' do
    expect(subject.css('select[name=procedure_id]')).to be_empty
  end

  context 'with >= 2 procedures' do
    let(:procedures_for_select) { [['Demande 1', 1], ['Demande 2', 2]] }

    it 'renders the procedure dropdown' do
      expect(subject.css('select[name=procedure_id]')).to be_present
    end
  end

  context 'without invites' do
    it 'does not render the shared_with_me checkbox' do
      expect(subject.css('input[name=shared_with_me]')).to be_empty
    end
  end

  context 'with invites' do
    let(:has_invites) { true }

    it 'renders the shared_with_me checkbox' do
      expect(subject.css('input[name=shared_with_me]')).to be_present
    end
  end

  it 'renders the submit button with count' do
    expect(subject.to_html).to include('Afficher les 12')
  end

  context 'when no dossier matches' do
    let(:filter) do
      instance_double(Users::DossierFilterService,
        active?: true,
        total_count: 0,
        counts: {
          procedure_ids: {},
          states: { 'brouillon' => 0, 'en_construction' => 0, 'en_instruction' => 0, 'accepte' => 0, 'refuse' => 0, 'sans_suite' => 0 },
          alerts: { 'nouveau_message' => 0, 'message_avec_attente_de_reponse' => 0, 'a_corriger' => 0, 'expire_bientot' => 0 },
          shared_with_me: 0,
        })
    end

    it 'renders a disabled apply button with the zero label' do
      expect(subject.to_html).to include('Aucun dossier ne correspond')
      expect(subject.css('input[type=submit][disabled]').size).to eq(1)
    end
  end
end
