# frozen_string_literal: true

describe 'Multiple dropdown after rebase removes an option', js: true do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  # >5 options so it renders as React MultipleSelect, not checkboxes
  let(:options) { ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf"] }
  let(:procedure) do
    create(:procedure, :published, :for_individual, types_de_champ_public: [
      { type: :multiple_drop_down_list, libelle: 'Zonage(s)', drop_down_options: options, mandatory: true },
    ])
  end
  let(:dossier) { create(:dossier, :en_construction, :with_individual, user:, procedure:) }
  let(:stable_id) { procedure.active_revision.root_public_types_de_champ.first.stable_id }

  before do
    # User had selected "Bravo" and "Charlie" before submitting
    champ = dossier.champ_data.find { _1.stable_id == stable_id }
    champ.update_columns(value: '["Bravo","Charlie"]')

    # Admin removes "Bravo" from options and publishes
    tdc = procedure.draft_revision.types_de_champ.find { _1.stable_id == stable_id }
    tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(tdc)
    tdc_to_update.update(drop_down_options: ["Alpha", "Charlie", "Delta", "Echo", "Foxtrot", "Golf"])
    procedure.publish_revision!(procedure.administrateurs.first)
    perform_enqueued_jobs
    dossier.reload
  end

  scenario 'user selects a valid option and submission succeeds (removed option is filtered out)' do
    login_as(user, scope: :user)
    visit modifier_dossier_path(dossier)

    # User tries to update their selection by adding "Alpha"
    select_autocomplete('Zonage(s)', 'Alpha')

    # Wait for autosave
    expect(page).to have_css('.autosave-status.succeeded', visible: true)

    click_on 'Déposer les modifications'

    # No validation error: removed option "Bravo" was filtered out by the component
    expect(page).to have_content('Votre dossier est déposé')
    expect(page).not_to have_content('« Zonage(s) » doit être dans les options proposées')

    # After submit, champ value contains only valid options: "Bravo" was dropped, "Alpha" was added
    champ = dossier.reload.root_public_champs.find { _1.stable_id == stable_id }
    expect(champ.selected_options).to match_array(["Alpha", "Charlie"])
  end
end
