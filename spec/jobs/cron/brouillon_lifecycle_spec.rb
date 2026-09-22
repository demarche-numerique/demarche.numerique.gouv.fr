# frozen_string_literal: true

# End-to-end lifecycle of a brouillon, driven by the real nightly cron jobs:
# notice 14 days before expiration (J-14), destruction at expiration (J),
# silent drains, trash and purge 14 days later, restore, extension, autosave
# and submission. These examples pin the current behaviour; every step of the
# removal_stage migration (issue #13915) must keep them green.
describe "Brouillon lifecycle" do
  # Far enough in the past that the seeded brouillons, created when the suite
  # starts, never come close to expiration during these examples: keep every
  # cron run within a few months of this date.
  let(:created_at) { Time.zone.local(2026, 1, 5, 22) }
  let(:user) { users.usager }
  let(:procedure) { procedures.individual }
  # A brouillon lives min(procedure conservation, 3 months) after its last edit.
  let(:expires_at) { created_at + 3.months }
  let(:notice_at) { expires_at - Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks }
  let(:dossier) do
    travel_to(created_at)
    create(:dossier, procedure:, user:).tap { autosave(it) }
  end

  # Every nightly job that removes brouillons.
  def run_crons(at)
    travel_to(at)
    Cron::ExpiredDossiersBrouillonDeletionJob.perform_now
    Cron::NeverTouchedDossiersBrouillonDeletionJob.perform_now
    Cron::ExpiredPrefilledDossiersDeletionJob.perform_now
    Cron::DiscardedBrouillonDossiersDeletionJob.perform_now
  end

  # What the usager's edit of a champ does (DossierEditConcern).
  def autosave(dossier)
    dossier.reload
    champ = dossier.champ_for_update(dossier.revision.public_root_type_de_champs.first, updated_by: user.email)
    Dossier.no_touching { champ.update!(value: "Projet #{Time.current.to_i}") }
    champ.update_timestamps
  end

  def warn!
    dossier
    run_crons(notice_at + 1.minute)
    dossier.reload
  end

  def gone?(dossier) = !Dossier.exists?(dossier.id)

  let(:notice_mail) { have_enqueued_mail(DossierMailer, :notify_brouillon_near_deletion) }
  let(:deletion_mail) { have_enqueued_mail(DossierMailer, :notify_brouillon_deletion) }

  it "warns the usager at J-14, then destroys the brouillon at J with a mail" do
    dossier
    expect(dossier.reload.expired_at).to eq(expires_at)

    expect { run_crons(notice_at - 1.minute) }.not_to have_enqueued_mail
    expect { run_crons(notice_at + 1.minute) }.to notice_mail.with([dossier], user.email)
      .and have_enqueued_mail.exactly(:once)

    dossier.reload
    expect(dossier.brouillon_close_to_expiration_notice_sent_at).to eq(notice_at + 1.minute)
    # The mail announces expired_at: it moves to notice + 14 days.
    expect(dossier.expired_at).to eq(notice_at + 1.minute + 2.weeks)

    deletion_at = dossier.expired_at
    expect { run_crons(notice_at + 1.day) }.not_to have_enqueued_mail
    expect { run_crons(deletion_at - 1.minute) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(deletion_at + 1.minute) }.to deletion_mail.with([dossier.hash_for_deletion_mail], user.email)
      .and have_enqueued_mail.exactly(:once)
    expect(gone?(dossier)).to be(true)
    expect(DeletedDossier.exists?(dossier_id: dossier.id)).to be(false)
  end

  it "silently drains the brouillons nobody can be warned about" do
    travel_to(created_at)
    on_closed_procedure = create(:dossier, procedure: procedures.close, user:)
    preview = create(:dossier, procedure:, user:, for_procedure_preview: true)
    never_touched = create(:dossier, procedure: procedures.entreprise, user:)
    prefilled_without_user = create(:dossier, :prefilled, procedure:, user: nil)
    drained = [on_closed_procedure, preview, never_touched, prefilled_without_user]

    expect do
      run_crons(created_at + 5.days - 1.minute)
      expect(drained.none? { gone?(it) }).to be(true)

      run_crons(created_at + 5.days + 1.minute)
      expect(drained.map { gone?(it) }).to eq([false, false, false, true])

      run_crons(created_at + 2.weeks - 1.minute)
      expect(gone?(never_touched)).to be(false)
      run_crons(created_at + 2.weeks + 1.minute)
      expect(gone?(never_touched)).to be(true)

      # Never warned: they are destroyed at expired_at itself.
      run_crons(notice_at + 1.minute)
      expect(on_closed_procedure.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil
      expect(preview.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil

      run_crons(expires_at - 1.minute)
      expect(gone?(on_closed_procedure) || gone?(preview)).to be(false)
      run_crons(expires_at + 1.minute)
      expect(gone?(on_closed_procedure) && gone?(preview)).to be(true)
    end.not_to have_enqueued_mail

    expect(DeletedDossier.where(dossier_id: drained.map(&:id))).to be_empty
  end

  it "purges a trashed brouillon 14 days after the trash, without warning it" do
    dossier
    trashed_at = notice_at - 1.day
    travel_to(trashed_at)
    dossier.hide_and_keep_track!(user, :user_request)

    expect do
      run_crons(notice_at + 1.minute)
      run_crons(trashed_at + Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks - 1.minute)
    end.not_to have_enqueued_mail
    expect(dossier.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil

    expect { run_crons(trashed_at + Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks + 1.minute) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(true)
    # A brouillon leaves no DeletedDossier behind (DeletedDossier.create_from_dossier).
    expect(DeletedDossier.exists?(dossier_id: dossier.id)).to be(false)
  end

  it "keeps the notice of a brouillon restored from the trash, and destroys it at the announced date" do
    warn!
    deletion_at = dossier.expired_at

    travel_to(notice_at + 2.days)
    dossier.hide_and_keep_track!(user, :user_request)
    travel_to(notice_at + 5.days)
    dossier.restore(user)

    expect(dossier.reload.brouillon_close_to_expiration_notice_sent_at).to be_present
    expect(dossier.expired_at).to eq(deletion_at)

    expect { run_crons(deletion_at - 1.minute) }.not_to have_enqueued_mail
    expect { run_crons(deletion_at + 1.minute) }.to deletion_mail.with([dossier.hash_for_deletion_mail], user.email)
    expect(gone?(dossier)).to be(true)
  end

  # CURRENT BEHAVIOUR, flipped by PR 7 (brouillon-removal-07-restore-fix): a
  # restored brouillon will go back to "retained", get a new notice and 14 more
  # days. Today its old notice still counts, so it is destroyed the very night
  # of the restore, without any new notice.
  it "destroys the same night a brouillon restored after its notice is older than 14 days" do
    warn!

    travel_to(notice_at + 10.days)
    dossier.hide_and_keep_track!(user, :user_request)
    # A hidden brouillon is left alone at J…
    expect { run_crons(notice_at + 15.days) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    # …and restored before its purge (trash + 14 days).
    restored_at = notice_at + 20.days
    travel_to(restored_at)
    dossier.restore(user)

    expect { run_crons(restored_at + 1.hour) }.to deletion_mail.with([dossier.hash_for_deletion_mail], user.email)
      .and have_enqueued_mail.exactly(:once)
    expect(gone?(dossier)).to be(true)
  end

  it "gives a new conservation period when the usager extends it after the notice" do
    warn!
    old_deletion_at = dossier.expired_at

    travel_to(notice_at + 3.days)
    dossier.extend_conservation(procedure.duree_conservation_dossiers_dans_ds.months)

    dossier.reload
    expect(dossier.brouillon_close_to_expiration_notice_sent_at).to be_nil
    # Counted from the last edit: 3 months + 3 months of extension.
    expect(dossier.expired_at).to eq(created_at + 6.months)

    expect { run_crons(old_deletion_at + 1.minute) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(dossier.expired_at - 2.weeks + 1.minute) }.to notice_mail.with([dossier], user.email)
  end

  it "cancels the notice when the usager edits the brouillon" do
    warn!
    old_deletion_at = dossier.expired_at

    edited_at = notice_at + 3.days
    travel_to(edited_at)
    autosave(dossier)

    dossier.reload
    expect(dossier.brouillon_close_to_expiration_notice_sent_at).to be_nil
    expect(dossier.expired_at).to eq(edited_at + 3.months)

    expect { run_crons(old_deletion_at + 1.minute) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(edited_at + 3.months - 2.weeks + 1.minute) }.to notice_mail.with([dossier], user.email)
  end

  it "leaves the brouillon cycle once submitted" do
    warn!
    old_deletion_at = dossier.expired_at

    travel_to(notice_at + 3.days)
    dossier.passer_en_construction!
    expect(dossier.reload.expired_at).to be_nil

    expect { run_crons(old_deletion_at + 1.minute) }.not_to have_enqueued_mail
    expect(dossier.reload).to be_en_construction
  end
end
