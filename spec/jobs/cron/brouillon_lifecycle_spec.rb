# frozen_string_literal: true

# End-to-end lifecycle of a brouillon, driven by the real nightly cron jobs.
# Every delay comes from the constants the jobs read (see the lets below).
# These examples pin the current behaviour; every step of the removal_stage
# migration (issue #13915) must keep them green.
describe "Brouillon lifecycle" do
  # Far enough in the past that the seeded brouillons, created when the suite
  # starts, never come close to expiration during these examples: keep every
  # cron run within a few months of this date.
  let(:created_at) { Time.zone.local(2026, 1, 5, 22) }
  let(:user) { users.usager }
  let(:procedure) { procedures.individual }

  # How long a brouillon lives after its last edit: min(procedure conservation,
  # this), and the seeded procedure keeps its dossiers longer.
  let(:brouillon_lifetime) { Expired::MONTHS_BEFORE_BROUILLON_EXPIRATION.months }
  # How long before expiration the usager is warned, hence how long a warned
  # brouillon survives its notice.
  let(:notice_period) { Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks }
  # How long a brouillon nobody ever filled in survives: never touched since
  # its creation, or prefilled and never claimed.
  let(:never_touched_lifetime) { Expired::WEEKS_BEFORE_NEVER_TOUCHED_BROUILLON_EXPIRATION.weeks }
  # How long a trashed brouillon stays in the trash before its purge.
  let(:trash_period) { Dossier::REMAINING_WEEKS_BEFORE_DELETION.weeks }
  # What the usager's "extend" button adds to the conservation.
  let(:extension) { procedure.duree_conservation_dossiers_dans_ds.months }

  let(:expires_at) { created_at + brouillon_lifetime }
  let(:notice_at) { expires_at - notice_period }
  # Edited once at its creation, so that it is not drained as never touched.
  let(:dossier) do
    travel_to(created_at)
    create(:dossier, procedure:, user:).tap { autosave(it) }
  end

  let(:notice_mail) { have_enqueued_mail(DossierMailer, :notify_brouillon_near_deletion) }
  let(:deletion_mail) { have_enqueued_mail(DossierMailer, :notify_brouillon_deletion) }

  # Every nightly job that removes brouillons.
  def run_crons(at)
    travel_to(at)
    Cron::ExpiredDossiersBrouillonDeletionJob.perform_now
    Cron::NeverTouchedDossiersBrouillonDeletionJob.perform_now
    Cron::DiscardedBrouillonDossiersDeletionJob.perform_now
  end

  # Cron runs just around a threshold: the first one must not act, the second one must.
  def just_before(at) = at - 1.minute
  def just_after(at) = at + 1.minute

  # What the usager's edit of a champ does (DossierEditConcern).
  def autosave(dossier)
    dossier.reload
    champ = dossier.champ_for_update(dossier.revision.public_root_type_de_champs.first, updated_by: user.email)
    Dossier.no_touching { champ.update!(value: "Projet #{Time.current.to_i}") }
    champ.update_timestamps
  end

  def warn!
    dossier
    run_crons(just_after(notice_at))
    dossier.reload
  end

  def gone?(dossier) = !Dossier.exists?(dossier.id)

  # Cron::ExpiredDossiersBrouillonDeletionJob: sends the notice, then destroys
  # the brouillon once the notice period is over.
  it "warns the usager at J-14, then destroys the brouillon at J with a mail" do
    dossier
    expect(dossier.reload.expired_at).to eq(expires_at)

    expect { run_crons(just_before(notice_at)) }.not_to have_enqueued_mail
    expect { run_crons(just_after(notice_at)) }.to notice_mail.with([dossier], user.email)
      .and have_enqueued_mail.exactly(:once)

    # The mail announces expired_at: it moves to a notice period after the notice.
    deletion_at = dossier.reload.expired_at
    expect(deletion_at).to eq(just_after(notice_at) + notice_period)

    expect { run_crons(just_before(deletion_at)) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(just_after(deletion_at)) }.to deletion_mail.with([dossier.hash_for_deletion_mail], user.email)
      .and have_enqueued_mail.exactly(:once)
    expect(gone?(dossier)).to be(true)
    expect(DeletedDossier.exists?(dossier_id: dossier.id)).to be(false)
  end

  # Cron::ExpiredDossiersBrouillonDeletionJob: no destruction at the announced
  # date, a new notice before the new one. Reset by Dossier#extend_conservation.
  it "gives a new conservation period when the usager extends it after the notice" do
    warn!
    old_deletion_at = dossier.expired_at

    travel_to(notice_at + 3.days)
    dossier.extend_conservation(extension)

    # Counted from the last edit.
    expect(dossier.reload.expired_at).to eq(created_at + brouillon_lifetime + extension)

    expect { run_crons(just_after(old_deletion_at)) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(just_after(dossier.expired_at - notice_period)) }.to notice_mail.with([dossier], user.email)
  end

  # Cron::ExpiredDossiersBrouillonDeletionJob: no destruction at the announced
  # date, a new notice before the new one. Reset by ChampData#update_timestamps.
  it "cancels the notice when the usager edits the brouillon" do
    warn!
    old_deletion_at = dossier.expired_at

    edited_at = notice_at + 3.days
    travel_to(edited_at)
    autosave(dossier)

    expect(dossier.reload.expired_at).to eq(edited_at + brouillon_lifetime)

    expect { run_crons(just_after(old_deletion_at)) }.not_to have_enqueued_mail
    expect(gone?(dossier)).to be(false)

    expect { run_crons(just_after(edited_at + brouillon_lifetime - notice_period)) }.to notice_mail.with([dossier], user.email)
  end

  # None of them sends a mail: Cron::NeverTouchedDossiersBrouillonDeletionJob
  # removes the ones nobody ever filled in, Cron::ExpiredDossiersBrouillonDeletionJob
  # the others (deletion without notice).
  it "silently drains the brouillons nobody can be warned about" do
    travel_to(created_at)
    on_closed_procedure = create(:dossier, procedure: procedures.close, user:)
    preview = create(:dossier, procedure:, user:, for_procedure_preview: true)
    never_touched = create(:dossier, procedure: procedures.entreprise, user:)
    prefilled_without_user = create(:dossier, :prefilled, procedure:, user: nil)
    drained = [on_closed_procedure, preview, never_touched, prefilled_without_user]

    expect do
      # Cron::NeverTouchedDossiersBrouillonDeletionJob: the prefilled one nobody
      # claimed and the one nobody ever edited, after the same delay.
      run_crons(just_before(created_at + never_touched_lifetime))
      expect(drained.map { gone?(it) }).to eq([false, false, false, false])
      run_crons(just_after(created_at + never_touched_lifetime))
      expect(drained.map { gone?(it) }).to eq([false, false, true, true])

      # Cron::ExpiredDossiersBrouillonDeletionJob, without notice: never warned,
      # they are destroyed at expired_at itself.
      run_crons(just_after(notice_at))
      expect(on_closed_procedure.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil
      expect(preview.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil

      run_crons(just_before(expires_at))
      expect(drained.map { gone?(it) }).to eq([false, false, true, true])
      run_crons(just_after(expires_at))
      expect(drained.map { gone?(it) }).to eq([true, true, true, true])
    end.not_to have_enqueued_mail

    expect(DeletedDossier.where(dossier_id: drained.map(&:id))).to be_empty
  end

  # Cron::DiscardedBrouillonDossiersDeletionJob purges it, without any mail.
  it "purges a trashed brouillon a trash period after the trash" do
    travel_to(created_at)
    dossier = create(:dossier, :with_individual, procedure:, user:)
    trashed_at = created_at + 1.day
    travel_to(trashed_at)
    dossier.hide_and_keep_track!(user, :user_request)
    purge_at = trashed_at + trash_period

    expect do
      run_crons(just_before(purge_at))
      expect(gone?(dossier)).to be(false)
      run_crons(just_after(purge_at))
      expect(gone?(dossier)).to be(true)
    end.not_to have_enqueued_mail

    expect(DeletedDossier.exists?(dossier_id: dossier.id)).to be(false)
  end

  # Cron::DiscardedBrouillonDossiersDeletionJob leaves it alone once restored.
  it "keeps a brouillon restored from the trash before its purge" do
    travel_to(created_at)
    dossier = create(:dossier, :with_individual, procedure:, user:)
    trashed_at = created_at + 1.day
    travel_to(trashed_at)
    dossier.hide_and_keep_track!(user, :user_request)
    travel_to(trashed_at + 1.day)
    dossier.restore(user)

    run_crons(just_after(trashed_at + trash_period))
    expect(gone?(dossier)).to be(false)
  end
end
