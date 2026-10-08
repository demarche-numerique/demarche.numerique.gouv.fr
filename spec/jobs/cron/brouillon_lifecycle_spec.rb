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

  let(:expires_at) { created_at + brouillon_lifetime }
  let(:notice_at) { expires_at - notice_period }

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

  def gone?(dossier) = !Dossier.exists?(dossier.id)

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
end
