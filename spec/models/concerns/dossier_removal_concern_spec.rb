# frozen_string_literal: true

describe DossierRemovalConcern do
  let(:procedure) { procedures.individual }
  let(:user) { users.usager }
  let(:created_at) { Time.zone.local(2026, 1, 5, 22) }
  # Never edited: it expires 3 months after its creation.
  let(:expires_at) { created_at + 3.months }
  let!(:brouillon) do
    travel_to(created_at)
    create(:dossier, procedure:, user:)
  end
  let(:due_at) { created_at + 1.month }

  def stage!(dossier, stage) = dossier.update_columns(removal_stage: stage, removal_due_at: nil)

  def count_queries(&)
    count = 0
    ActiveSupport::Notifications.subscribed(-> (*) { count += 1 }, 'sql.active_record', &)
    count
  end

  describe 'removal_stage' do
    it 'has no bang method, which would write the stage around the compare-and-set' do
      expect(brouillon).not_to respond_to(:removal_retained!)
    end
  end

  describe '.move_removal!' do
    let(:hidden) { create(:dossier, procedure:, user:).tap { stage!(it, 'hidden') } }
    let(:expired_at) { created_at + 2.months }

    it 'moves only the rows still in a from stage, derives the due date and returns their ids' do
      moved = Dossier.where(id: [brouillon, hidden]).move_removal!(from: :retained, to: :warned, expired_at:)

      expect(moved).to eq([brouillon.id])
      expect(brouillon.reload).to have_attributes(removal_stage: 'warned', removal_due_at: expired_at, expired_at:)
      expect(hidden.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: nil)
    end

    it 'dates retained at the notice and hidden at the given due date' do
      Dossier.where(id: brouillon).move_removal!(from: :retained, to: :retained, expired_at:)
      expect(brouillon.reload).to have_attributes(removal_stage: 'retained', removal_due_at: expired_at - 2.weeks, expired_at:)

      Dossier.where(id: [brouillon, hidden]).move_removal!(from: [:retained, :warned], to: :hidden, due_at:)
      expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: due_at, expired_at:)
    end

    it 'works on a relation with joins, order and limit' do
      selection = Dossier.where(id: [brouillon, hidden]).with_notifiable_procedure.order(id: :desc).limit(1)

      expect(selection.move_removal!(from: [:retained, :hidden], to: :warned, expired_at:)).to eq([hidden.id])
    end

    it 'refuses a move out of the graph, writing nothing' do
      expect { Dossier.where(id: brouillon).move_removal!(from: :warned, to: :warned, expired_at:) }
        .to raise_error(DossierRemovalConcern::InvalidRemovalMove, 'warned -> warned')
      expect { Dossier.where(id: brouillon).move_removal!(from: [:retained, nil], to: :retained, expired_at:) }
        .to raise_error(DossierRemovalConcern::InvalidRemovalMove)

      expect(brouillon.reload).to have_attributes(removal_stage: 'retained', expired_at: expires_at)
    end
  end

  describe '#move_removal!' do
    let(:expired_at) { created_at + 2.months }

    it 'moves the dossier and keeps it in sync in memory' do
      expect(brouillon.move_removal!(from: :retained, to: :warned, expired_at:)).to be(true)

      expect(brouillon).to have_attributes(removal_stage: 'warned', removal_due_at: expired_at, expired_at:)
      expect(brouillon.changed).to be_empty
      expect(brouillon.reload).to have_attributes(removal_stage: 'warned', removal_due_at: expired_at, expired_at:)
    end

    it 'writes nothing when the dossier left the from stage since it was loaded' do
      Dossier.where(id: brouillon).move_removal!(from: :retained, to: :hidden, due_at:)

      expect(brouillon.move_removal!(from: :retained, to: :warned, expired_at:)).to be(false)

      expect(brouillon).to be_removal_retained
      expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: due_at, expired_at: expires_at)
    end
  end

  describe 'entering and leaving the managed states' do
    it 'enters every new brouillon as retained, dated when expired_at is written' do
      travel_to(created_at)
      prefilled_without_user = create(:dossier, :prefilled, procedure:, user: nil)
      preview = create(:dossier, procedure:, user:, for_procedure_preview: true)

      [brouillon, prefilled_without_user, preview].each do
        expect(it.reload).to have_attributes(removal_stage: 'retained', removal_due_at: expires_at - 2.weeks, expired_at: expires_at)
      end
    end

    it 'enters a clone as retained, whatever the stage or the state of its parent' do
      stage!(brouillon, 'hidden')

      expect(brouillon.clone).to be_removal_retained
      expect(dossiers.en_construction.clone).to be_removal_retained
    end

    it 'leaves the other states out' do
      expect(dossiers.en_construction.reload).not_to be_removal_managed
      expect(dossiers.accepte.reload).not_to be_removal_managed
    end

    it 'leaves on submission, even with a stage written after the dossier was loaded' do
      stage!(brouillon, nil)
      Dossier.where(id: brouillon).update_all(removal_stage: 'warned', removal_due_at: due_at)

      brouillon.passer_en_construction!

      expect(brouillon.reload).to have_attributes(removal_stage: nil, removal_due_at: nil)
    end
  end

  describe '.warn_removal!' do
    let(:warned_at) { expires_at - 2.weeks + 1.minute }
    let(:hidden) { create(:dossier, procedure:, user:).tap { stage!(it, 'hidden') } }

    it 'warns the retained brouillons, destroyed two weeks later' do
      expect(Dossier.where(id: [brouillon, hidden]).warn_removal!(warned_at)).to eq([brouillon.id])

      expect(brouillon.reload).to have_attributes(
        removal_stage: 'warned',
        removal_due_at: warned_at + 2.weeks,
        expired_at: warned_at + 2.weeks,
        brouillon_close_to_expiration_notice_sent_at: warned_at
      )
      expect(hidden.reload.brouillon_close_to_expiration_notice_sent_at).to be_nil
    end
  end

  describe '#restart_removal!' do
    it 'takes a warned brouillon back to retained for a full period from its last edit, cancelling the notice' do
      warned = create(:dossier, :warned, procedure:, user:, warned_at: expires_at - 2.weeks)
      warned.update_columns(last_champ_updated_at: created_at + 1.month)

      expect(warned.restart_removal!).to be(true)

      expect(warned.reload).to have_attributes(
        removal_stage: 'retained',
        removal_due_at: created_at + 4.months - 2.weeks,
        expired_at: created_at + 4.months,
        brouillon_close_to_expiration_notice_sent_at: nil
      )
    end

    it 'leaves a trashed brouillon alone' do
      brouillon.hide_removal!(created_at)

      expect(brouillon.restart_removal!).to be(false)
      expect(brouillon.reload).to be_removal_hidden
    end
  end

  describe '#hide_removal!' do
    it 'purges two weeks after the first hiding' do
      expect(brouillon.hide_removal!(due_at)).to be(true)
      expect(brouillon.hide_removal!(due_at + 1.day)).to be(false)

      expect(brouillon.reload).to have_attributes(removal_stage: 'hidden', removal_due_at: due_at + 2.weeks, expired_at: expires_at)
    end
  end

  # CURRENT BEHAVIOUR, changed by PR 7: a restored brouillon keeps its notice.
  describe '#restore_removal!' do
    it 'takes a brouillon warned before its trash back to warned, at the date its notice announced' do
      warned_at = expires_at - 2.weeks
      warned = create(:dossier, :warned, procedure:, user:, warned_at:)
      warned.hide_removal!(warned_at + 1.day)

      expect(warned.restore_removal!).to be(true)

      expect(warned.reload).to have_attributes(removal_stage: 'warned', removal_due_at: warned_at + 2.weeks, expired_at: warned_at + 2.weeks)
    end

    it 'takes a brouillon never warned back to retained' do
      brouillon.hide_removal!(created_at)

      expect(brouillon.restore_removal!).to be(true)

      expect(brouillon.reload).to have_attributes(removal_stage: 'retained', removal_due_at: expires_at - 2.weeks, expired_at: expires_at)
    end

    it 'leaves a brouillon the expiration still hides in the trash' do
      brouillon.update!(hidden_by_expired_at: created_at)
      brouillon.hide_removal!(created_at)

      expect(brouillon.restore_removal!).to be(false)
      expect(brouillon.reload).to be_removal_hidden
    end
  end

  describe '#refresh_removal!' do
    it 'follows a save moving the expiration of a retained brouillon, and writes nothing when it did not move' do
      travel_to(created_at + 1.month)
      brouillon.update!(autorisation_donnees: false)

      expect(brouillon.reload).to have_attributes(
        removal_stage: 'retained',
        removal_due_at: created_at + 4.months - 2.weeks,
        expired_at: created_at + 4.months
      )
      brouillon.duree_totale_conservation_in_months # loads the procedure
      expect(count_queries { brouillon.refresh_removal! }).to eq(0)
    end

    it 'keeps the dates of a warned brouillon' do
      warned = create(:dossier, :warned, procedure:, user:, warned_at: expires_at - 2.weeks)

      travel_to(expires_at - 1.week)
      warned.update!(autorisation_donnees: false)

      expect(warned.reload).to have_attributes(removal_stage: 'warned', removal_due_at: expires_at, expired_at: expires_at)
    end

    it 'does not overwrite a notice sent since the dossier was loaded' do
      warned_at = expires_at - 2.weeks
      travel_to(warned_at)
      Dossier.where(id: brouillon).warn_removal!(warned_at)

      travel_to(warned_at + 1.hour)
      brouillon.update!(autorisation_donnees: false)

      expect(brouillon.reload).to have_attributes(
        removal_stage: 'warned',
        removal_due_at: expires_at,
        expired_at: expires_at,
        brouillon_close_to_expiration_notice_sent_at: warned_at
      )
    end
  end
end
