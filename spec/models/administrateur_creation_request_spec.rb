# frozen_string_literal: true

describe AdministrateurCreationRequest do
  let(:requester) { create(:super_admin) }
  let(:validator) { create(:super_admin) }

  def emails(count, domain: 'numerique.gouv.fr') = Array.new(count) { "agent.#{it}@#{domain}" }

  describe '.parse_emails' do
    it 'extracts lowercase unique addresses from any pasted format' do
      text = <<~TEXT
        Camille Martin <Camille.Martin@numerique.gouv.fr>, louis@culture.gouv.fr; sarah@ars.sante.fr
        julie@ars.sante.fr\tmailto:lucas@numerique.gouv.fr "camille.martin@numerique.gouv.fr"
      TEXT

      expect(described_class.parse_emails(text)).to eq([
        'camille.martin@numerique.gouv.fr',
        'louis@culture.gouv.fr',
        'sarah@ars.sante.fr',
        'julie@ars.sante.fr',
        'lucas@numerique.gouv.fr',
      ])
    end

    it 'never keeps markup around an address' do
      expect(described_class.parse_emails('<script>alert(1)</script><b>x@y.fr</b>')).to eq(['x@y.fr'])
    end

    it { expect(described_class.parse_emails(nil)).to eq([]) }
  end

  describe 'validations' do
    subject(:creation_request) { described_class.new(requester:, emails: list, state: :pending) }

    context 'without any address' do
      let(:list) { [] }

      it do
        expect(creation_request).not_to be_valid
        expect(creation_request.errors).to be_of_kind(:emails, :too_short)
      end
    end

    context 'with 100 addresses' do
      let(:list) { emails(100) }

      it { is_expected.to be_valid }
    end

    context 'with 101 addresses' do
      let(:list) { emails(101) }

      it do
        expect(creation_request).not_to be_valid
        expect(creation_request.errors).to be_of_kind(:emails, :too_long)
      end
    end

    context 'when the daily quota of the requester would be exceeded' do
      let(:list) { emails(2, domain: 'culture.gouv.fr') }

      before do
        3.times { |i| described_class.create!(requester:, emails: emails(100, domain: "d#{i}.fr"), state: :approved) }
      end

      it do
        expect(creation_request).not_to be_valid
        expect(creation_request.errors).to be_of_kind(:emails, :daily_quota_exceeded)
      end

      it 'ignores the requests of other super admins, older ones and dropped ones' do
        described_class.where(requester:).first.update!(created_at: 25.hours.ago)
        expect(creation_request).to be_valid

        described_class.where(requester:).update_all(state: :refused, created_at: Time.current)
        expect(creation_request).to be_valid
      end
    end
  end

  describe '#requires_validation?' do
    it 'is required above 10 addresses' do
      expect(described_class.new(emails: emails(10))).not_to be_requires_validation
      expect(described_class.new(emails: emails(11))).to be_requires_validation
    end
  end

  describe '#domains' do
    it 'counts the addresses per domain, most frequent first' do
      request = described_class.new(emails: ['a@x.fr', 'b@y.fr', 'c@y.fr'])
      expect(request.domains).to eq([['y.fr', 2], ['x.fr', 1]])
    end
  end

  describe '#approve! and #refuse!' do
    let!(:creation_request) { described_class.create!(requester:, emails: emails(11), state: :pending) }

    it 'approves a pending request only once' do
      expect(creation_request.approve!(validator)).to be(true)
      expect(creation_request.reload).to have_attributes(state: 'approved', validator_id: validator.id, decided_at: be_present)

      expect(creation_request.approve!(validator)).to be(false)
      expect(creation_request.refuse!(validator)).to be(false)
      expect(creation_request.reload).to be_approved
    end

    it 'refuses a pending request' do
      expect(creation_request.refuse!(validator)).to be(true)
      expect(creation_request.reload).to have_attributes(state: 'refused', validator_id: validator.id)
      expect(creation_request.approve!(validator)).to be(false)
    end

    it 'rejects an expired request' do
      travel_to(24.hours.from_now + 1.second) do
        expect(creation_request).to be_expired
        expect(creation_request.approve!(validator)).to be(false)
      end
      expect(creation_request.reload).to be_pending
    end

    it 'rejects a cancelled request' do
      expect(creation_request.cancel!).to be(true)
      expect(creation_request.approve!(validator)).to be(false)
      expect(creation_request.reload).to be_cancelled
    end
  end

  describe '#create_accounts!' do
    let(:existing) { administrateurs.default }
    let(:creation_request) do
      described_class.create!(requester:, emails: ['new.admin@numerique.gouv.fr', existing.email, 'bad@@numerique.gouv.fr'], state: :approved)
    end

    it 'creates the new administrateurs, skips the existing ones and reports the refused ones' do
      expect { creation_request.create_accounts! }
        .to change { Administrateur.by_email('new.admin@numerique.gouv.fr') }.from(nil)
        .and have_enqueued_mail(AdministrationMailer).once

      expect(creation_request.reload.results).to eq(
        'new.admin@numerique.gouv.fr' => 'created',
        existing.email => 'already_administrateur',
        'bad@@numerique.gouv.fr' => 'invalid'
      )
      expect(Administrateur.by_email('new.admin@numerique.gouv.fr').procedures.count).to eq(1)
    end

    it 'runs once' do
      creation_request.create_accounts!
      expect(User).not_to receive(:create_or_promote_to_administrateur)
      creation_request.create_accounts!
    end
  end
end
