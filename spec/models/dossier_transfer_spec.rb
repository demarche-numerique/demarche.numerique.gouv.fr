# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DossierTransfer, type: :model do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:dossier) { create(:dossier, user: user) }

  describe 'initiate' do
    subject { DossierTransfer.initiate(other_user.email, [dossier]) }

    it 'should send transfer request' do
      expect(subject.email).to eq(other_user.email)
      expect(subject.dossiers).to eq([dossier])
      expect(dossier.transfer).to eq(subject)
      expect(dossier.user).to eq(user)
      expect(dossier.transfer_logs.count).to eq(0)
    end

    describe 'accept' do
      let(:transfer_log) { dossier.transfer_logs.first }

      before do
        DossierTransfer.accept(subject.id, other_user)
        dossier.reload
      end

      it 'should transfer dossier' do
        expect(DossierTransfer.count).to eq(0)
        expect(dossier.transfer).to be_nil
        expect(dossier.user).to eq(other_user)
        expect(dossier.transfer_logs.count).to eq(1)
        expect(transfer_log.dossier).to eq(dossier)
        expect(transfer_log.from).to eq(user.email)
        expect(transfer_log.to).to eq(other_user.email)
      end
    end

    describe 'with_dossiers' do
      before { subject }

      it { expect(DossierTransfer.with_dossiers.count).to eq(1) }

      context "when dossier deleted" do
        before { dossier.update(hidden_by_user_at: 1.hour.ago) }

        it { expect(DossierTransfer.with_dossiers.count).to eq(0) }
      end
    end
  end

  describe '.accept' do
    let(:transfer) { DossierTransfer.initiate(other_user.email, [dossier]) }

    it 'returns true when the transfer is accepted' do
      expect(DossierTransfer.accept(transfer.id, other_user)).to be(true)
    end

    it 'returns false when the transfer has expired' do
      transfer.update!(created_at: (DossierTransfer::EXPIRATION_LIMIT + 1.day).ago)

      expect(DossierTransfer.accept(transfer.id, other_user)).to be(false)
      expect(dossier.reload.user).to eq(user)
    end

    it 'returns false when the transfer does not exist' do
      expect(DossierTransfer.accept(0, other_user)).to be(false)
    end
  end

  describe '#destroy_and_nullify' do
    let(:transfer) { create(:dossier_transfer) }
    let(:dossier) { create(:dossier, user: user, transfer: transfer) }
    let(:deleted_dossier) { create(:dossier, user: user, transfer: dossier.transfer) }

    before do
      deleted_dossier.update(hidden_by_user_at: 1.hour.ago)
    end

    it 'nullify transfer relationship on dossier' do
      expect(dossier.transfer).to eq(transfer)
      transfer.destroy_and_nullify
      expect(dossier.reload.transfer).to be_nil
    end
  end

  describe '#destroy_stale' do
    let(:transfer) { create(:dossier_transfer, created_at: 1.month.ago) }
    let(:dossier) { create(:dossier, user: user, transfer: transfer) }
    let(:deleted_dossier) { create(:dossier, user: user, transfer: dossier.transfer) }

    before do
      deleted_dossier.update(hidden_by_user_at: 1.hour.ago)
    end

    it 'nullify the transfer on discarded dossier' do
      DossierTransfer.destroy_stale
      expect(DossierTransfer.count).to eq(0)
    end
  end

  describe "validation" do
    let(:email) { build(:dossier_transfer).email }

    subject { build(:dossier_transfer, email: email) }

    it "factory is valid" do
      expect(subject).to be_valid
    end

    context "when email is blank" do
      let(:email) { "" }

      it "requires a valid email" do
        expect(subject).to be_invalid
      end
    end

    context "when email is not an email" do
      let(:email) { "test" }

      it "requires a valid email" do
        expect(subject).to be_invalid
      end
    end

    context "when email contains spaces and uppercase characters" do
      let(:email) { "  Foo@Example.COM " }

      it "sanitizes the email on assignment" do
        expect(subject.email).to eq("foo@example.com")
      end
    end
  end
end
