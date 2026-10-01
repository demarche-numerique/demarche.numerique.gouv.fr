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

  it "leaves a trashed dossier en construction to the legacy columns" do
    dossier = dossiers.en_construction
    dossier.hide_and_keep_track!(dossier.user, :user_request)

    expect(dossier.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
  end

  describe "the notice" do
    let(:notice_period) { Expired::REMAINING_WEEKS_BEFORE_EXPIRATION.weeks }

    def warn(dossier) = dossier.update!(brouillon_close_to_expiration_notice_sent_at: Time.current)

    it "moves a warned brouillon to warned, due a notice period after the notice" do
      warn(brouillon)

      expect(brouillon.reload).to have_attributes(removal_stage: 'warned', removal_due_at: Time.current + notice_period)
    end

    it "gives a brouillon extended by its usager back to the legacy columns" do
      warn(brouillon)
      brouillon.extend_conservation(1.month)

      expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
    end

    it "gives a brouillon whose procedure reset its expiration back to the legacy columns" do
      warn(brouillon)
      ResetExpiringDossiersJob.perform_now(brouillon.procedure)

      expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
    end

    it "moves a warned brouillon to hidden in the trash, and back to warned once restored" do
      warn(brouillon)
      brouillon.hide_and_keep_track!(brouillon.user, :user_request)
      expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: Time.current + trash_period)

      brouillon.restore(brouillon.user)
      expect(brouillon.reload).to have_attributes(removal_stage: 'warned', removal_due_at: Time.current + notice_period)
    end

    describe ".warn_removal!" do
      def warn_in_sql(dossier)
        Dossier.where(id: dossier).warn_removal!(Time.current)
        dossier.reload
      end

      it "warns a brouillon" do
        expect(warn_in_sql(brouillon)).to have_attributes(
          brouillon_close_to_expiration_notice_sent_at: Time.current,
          removal_stage: 'warned',
          removal_due_at: Time.current + notice_period
        )
      end

      it "leaves alone a dossier submitted or trashed since it was loaded" do
        trashed = create(:dossier, :brouillon).tap { it.hide_and_keep_track!(it.user, :user_request) }

        expect(warn_in_sql(dossiers.en_construction)).to have_attributes(removal_stage: nil, removal_due_at: nil)
        expect(warn_in_sql(trashed)).to have_attributes(removal_stage: 'hidden', removal_due_at: Time.current + trash_period)
      end
    end

    describe "#update_columns_and_unwarn" do
      let(:attributes) { { brouillon_close_to_expiration_notice_sent_at: nil, last_champ_updated_at: Time.current } }

      it "takes a warned brouillon out of its stage, without leaving changes to save" do
        warn(brouillon)
        brouillon.update_columns_and_unwarn(attributes)

        expect(brouillon).to have_attributes(removal_stage: nil, removal_due_at: nil, changed?: false)
        expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil, brouillon_close_to_expiration_notice_sent_at: nil)
      end

      it "sees a notice written since the brouillon was loaded" do
        loaded = Dossier.find(brouillon.id)
        warn(brouillon)
        loaded.update_columns_and_unwarn(attributes)

        expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
      end

      it "leaves a trashed brouillon hidden" do
        brouillon.hide_and_keep_track!(brouillon.user, :user_request)
        brouillon.update_columns_and_unwarn(attributes)

        expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: Time.current + trash_period)
      end
    end
  end
end
