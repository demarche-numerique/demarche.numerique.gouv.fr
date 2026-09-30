# frozen_string_literal: true

describe DossierRemovalConcern do
  let(:trash_period) { Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks }
  let(:brouillon) { dossiers.brouillon }

  before { freeze_time }

  it "leaves an untrashed brouillon to the legacy columns" do
    expect(brouillon).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end

  it "moves a brouillon trashed by its usager to hidden, due after the trash period" do
    brouillon.hide_and_keep_track!(brouillon.user, :user_request)

    expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: Time.current + trash_period)
  end

  it "moves a brouillon hidden by expiration to hidden" do
    brouillon.hide_and_keep_track!(:automatic, :expired)

    expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: Time.current + trash_period)
  end

  it "keeps the first purge date of a brouillon hidden twice" do
    brouillon.hide_and_keep_track!(:automatic, :expired)
    travel 1.day
    brouillon.hide_and_keep_track!(brouillon.user, :user_request)

    expect(brouillon.reload.removal_due_at).to eq(1.day.ago + trash_period)
  end

  it "gives a brouillon restored by its usager back to the legacy columns" do
    brouillon.hide_and_keep_track!(brouillon.user, :user_request)
    brouillon.restore(brouillon.user)

    expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end

  it "gives an expired brouillon extended by its usager back to the legacy columns" do
    brouillon.hide_and_keep_track!(:automatic, :expired)
    brouillon.extend_conservation_and_restore(1.month, brouillon.user)

    expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end

  it "gives a brouillon whose procedure reset its expiration back to the legacy columns" do
    brouillon.update!(brouillon_close_to_expiration_notice_sent_at: 2.weeks.ago)
    brouillon.hide_and_keep_track!(:automatic, :expired)
    ResetExpiringDossiersJob.perform_now(brouillon.procedure)

    expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end

  it "makes a trashed brouillon due for purge once its purge date is past" do
    brouillon.hide_and_keep_track!(brouillon.user, :user_request)

    travel_to(brouillon.removal_due_at)
    expect(Dossier.trash_purge_due).not_to include(brouillon)
    travel 1.second
    expect(Dossier.trash_purge_due).to include(brouillon)
  end

  it "leaves a trashed dossier en construction to the legacy columns" do
    dossier = dossiers.en_construction
    dossier.hide_and_keep_track!(dossier.user, :user_request)

    expect(dossier.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end
end
