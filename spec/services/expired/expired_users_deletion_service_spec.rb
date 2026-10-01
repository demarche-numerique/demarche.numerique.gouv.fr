# frozen_string_literal: true

describe Expired::UsersDeletionService do
  let(:signed_in_not_expired) { (Expired::INACTIVE_USER_RETENTION_IN_YEAR - 1).years.ago }
  let(:signed_in_expired) { (Expired::INACTIVE_USER_RETENTION_IN_YEAR + 1).years.ago }
  let(:before_close_to_expiration) { nil }
  let(:notified_close_to_expiration) { (Expired::REMAINING_WEEKS_BEFORE_EXPIRATION - 1).weeks.ago }
  let(:due_close_to_expiration) { (Expired::REMAINING_WEEKS_BEFORE_EXPIRATION + 1).weeks.ago }
  let(:mail_double) do
    dbl = double()
    expect(dbl).to receive(:deliver_later).with(wait: 0)
    dbl
  end

  before { user && dossier }

  describe '#process_expired' do
    subject { Expired::UsersDeletionService.new.process_expired }

    context 'when user is expirable and have a dossier' do
      let(:dossier) { create(:dossier, user:, created_at: signed_in_expired) }

      context 'when user was not notified' do
        let(:user) { create(:user, :with_email_verified, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: before_close_to_expiration) }

        it 'update user.inactive_close_to_expiration_notice_sent_at ' do
          expect(UserMailer).to receive(:notify_inactive_close_to_deletion).with(user).and_return(mail_double)
          expect { subject }
            .to change { user.reload.inactive_close_to_expiration_notice_sent_at }
            .from(nil).to(anything)
        end
      end

      context 'user has been notified 1 week ago' do
        let(:user) { create(:user, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: notified_close_to_expiration) }

        it 'do nothing' do
          expect { subject }.not_to change { Dossier.count }
          expect { user.reload }.not_to raise_error
        end
      end

      context 'user has been notified 3 weeks ago' do
        let(:user) { create(:user, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: due_close_to_expiration) }

        it 'destroys user and dossier' do
          expect { subject }.to change { Dossier.count }.by(-1)
          expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        context 'when dossier brouillon' do
          let(:dossier) { create(:dossier, :brouillon, user:, created_at: signed_in_expired) }
          it 'destroys user and dossier' do
            expect { subject }.to change { Dossier.count }.by(-1)
            expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'when dossier en_construction' do
          let(:dossier) { create(:dossier, :en_construction, user:, created_at: signed_in_expired) }
          it 'destroys user and dossier' do
            expect { subject }.to change { Dossier.count }.by(-1)
            expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'when dossier en_instruction' do
          let(:dossier) { create(:dossier, :en_instruction, user:, created_at: signed_in_expired) }
          it 'does not do anything' do
            expect { subject }.not_to change { Dossier.count }
            expect { user.reload }.not_to raise_error
          end
        end

        context 'when dossier termine' do
          let(:dossier) { create(:dossier, :accepte, user:, created_at: signed_in_expired) }
          it 'marks dossier as hidden by user due to user_removal and remove user' do
            expect { subject }.to change { dossier.reload.hidden_by_user_at }.from(nil).to(anything)
            expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context 'when user is expirable but does not have a dossier' do
      let(:dossier) { nil }

      context 'when user was not notified' do
        let(:user) { create(:user, :with_email_verified, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: before_close_to_expiration) }

        it 'update user.inactive_close_to_expiration_notice_sent_at ' do
          expect(UserMailer).to receive(:notify_inactive_close_to_deletion).with(user).and_return(mail_double)
          expect { subject }
            .to change { user.reload.inactive_close_to_expiration_notice_sent_at }
            .from(nil).to(anything)
        end
      end

      context 'when user has been notified 1 week ago' do
        let(:user) { create(:user, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: notified_close_to_expiration) }

        it 'do nothing' do
          expect { subject }.not_to change { Dossier.count }
          expect { user.reload }.not_to raise_error
        end
      end

      context 'when user has been notified 3 weeks ago' do
        let(:user) { create(:user, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: due_close_to_expiration) }

        it 'destroys user and dossier' do
          subject
          expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'when the user signed in again after an earlier notice' do
      let(:dossier) { nil }
      let(:user) { create(:user, :with_email_verified, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: signed_in_expired - 1.year) }

      it 'warns the user again instead of deleting them' do
        expect(UserMailer).to receive(:notify_inactive_close_to_deletion).with(user).and_return(mail_double)

        subject
        expect(user.reload.inactive_close_to_expiration_notice_sent_at).to be > 1.minute.ago
      end
    end

    context 'when the user signs in while the notices are being sent' do
      let(:dossier) { nil }
      let(:user) { create(:user, :with_email_verified, current_sign_in_at: signed_in_expired) }

      it 'does not date a notice after that sign-in' do
        expect(UserMailer).to receive(:notify_inactive_close_to_deletion).with(user) do
          user.update_columns(current_sign_in_at: Time.current)
          mail_double
        end

        subject
        expect(user.reload.inactive_close_to_expiration_notice_sent_at).to be_nil
      end
    end

    context 'when the user email was never verified' do
      let(:dossier) { nil }
      let(:user) { create(:user, current_sign_in_at: signed_in_expired) }

      it 'starts the notice period without sending a mail that would be dropped' do
        expect(UserMailer).not_to receive(:notify_inactive_close_to_deletion)

        expect { subject }
          .to change { user.reload.inactive_close_to_expiration_notice_sent_at }
          .from(nil).to(anything)
      end
    end

    context 'when the notification phase raises' do
      let(:user) { create(:user, current_sign_in_at: signed_in_expired, inactive_close_to_expiration_notice_sent_at: due_close_to_expiration) }
      let(:dossier) { create(:dossier, :brouillon, user:, created_at: signed_in_expired) }

      it 'reports the error and still deletes the users of the other segment' do
        allow_any_instance_of(Expired::UsersDeletionService)
          .to receive(:send_inactive_close_to_expiration_notice)
          .and_raise(ActiveRecord::QueryCanceled)

        expect(Sentry).to receive(:capture_exception).with(ActiveRecord::QueryCanceled).twice

        subject
        expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#expired_users_without_dossiers' do
    let(:dossier) { nil }
    subject { Expired::UsersDeletionService.new.send(:expired_users_without_dossiers) }

    context 'when user current_sign_in_at is 1 year ago and has no dossier' do
      let(:user) { create(:user, current_sign_in_at: signed_in_not_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user current_sign_in_at is 3 year ago and has no dossier' do
      let(:user) { create(:user, current_sign_in_at: signed_in_expired) }
      it { is_expected.to include(user) }
    end

    context 'when user signed in once recently but last_sign_in_at is still old (regression #13260)' do
      let(:user) { create(:user, last_sign_in_at: signed_in_expired, current_sign_in_at: signed_in_not_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has an expert' do
      let(:user) { create(:user, expert: create(:expert), current_sign_in_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has an instructeur' do
      let(:user) { create(:user, instructeur: create(:instructeur), current_sign_in_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has an admin' do
      let(:user) { create(:user, administrateur: administrateurs.default, current_sign_in_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired but have a dossier' do
      let(:user) { users.admin.tap { it.update(current_sign_in_at: signed_in_expired) } }
      let(:dossier) { create(:dossier, :brouillon, user:, created_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user never signed in and was created more than two years ago' do
      let(:user) { create(:user, current_sign_in_at: nil, created_at: signed_in_expired) }
      it { is_expected.to include(user) }
    end

    context 'when user never signed in and was created recently' do
      let(:user) { create(:user, current_sign_in_at: nil, created_at: signed_in_not_expired) }
      it { is_expected.not_to include(user) }
    end
  end

  describe '#expired_users_with_dossiers' do
    let(:user) { create(:user, current_sign_in_at: signed_in_expired) }
    let(:dossier) { create(:dossier, :brouillon, user:, created_at: signed_in_expired) }
    subject { Expired::UsersDeletionService.new.send(:expired_users_with_dossiers) }

    context 'when user is not expired' do
      let(:user) { create(:user, current_sign_in_at: signed_in_not_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has a dossier brouillon' do
      let(:dossier) { create(:dossier, :brouillon, user:, created_at: signed_in_expired) }
      it { is_expected.to include(user) }
    end

    context 'when user is expired and has a many dossier brouillon' do
      before do
        create(:dossier, :brouillon, user:, created_at: signed_in_expired)
        create(:dossier, :brouillon, user:, created_at: signed_in_expired)
      end
      it { is_expected.to eq([user]) }
    end

    context 'when user is expired and has a dossier en_construction' do
      let(:dossier) { create(:dossier, :en_construction, user:, created_at: signed_in_expired) }
      it { is_expected.to include(user) }
    end

    context 'when user is expired and has a dossier en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, user:, created_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has a dossier en_instruction plus another one brouillon' do
      before do
        create(:dossier, :en_instruction, user:, created_at: signed_in_expired)
        create(:dossier, :brouillon, user:, created_at: signed_in_expired)
      end
      it { is_expected.to eq([]) }
    end

    context 'when user is expired and has a dossier termine' do
      let(:dossier) { create(:dossier, :accepte, user:, created_at: signed_in_expired) }
      it { is_expected.to include(user) }
    end

    context 'when user is expired and has an expert' do
      let(:dossier) { create(:dossier, user:, created_at: signed_in_expired) }
      let(:user) { create(:user, expert: create(:expert), current_sign_in_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has an instructeur' do
      let(:dossier) { create(:dossier, user:, created_at: signed_in_expired) }
      let(:user) { create(:user, instructeur: create(:instructeur), current_sign_in_at: signed_in_expired) }
      it { is_expected.not_to include(user) }
    end

    context 'when user is expired and has an admin' do
      let(:dossier) { create(:dossier, user:, created_at: signed_in_expired) }
      let(:user) { users.admin.tap { it.update(current_sign_in_at: signed_in_expired) } }
      it { is_expected.not_to include(user) }
    end
  end

  describe '#to_notify_only' do
    let(:dossier) { nil }
    let(:service) { Expired::UsersDeletionService.new }
    let(:user) { create(:user, current_sign_in_at: 4.years.ago) }
    let!(:oldest) { create(:user, current_sign_in_at: 6.years.ago) }
    let!(:newest) { create(:user, current_sign_in_at: 3.years.ago) }
    let!(:middle) { create(:user, current_sign_in_at: 5.years.ago) }

    subject { service.send(:to_notify_only, service.send(:expired_users_without_dossiers)) }

    it 'returns the least recently active users first' do
      expected = [oldest, middle, user, newest].map(&:id)

      expect(subject.pluck(:id) & expected).to eq(expected)
    end
  end
end
