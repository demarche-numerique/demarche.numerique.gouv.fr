# frozen_string_literal: true

describe ProcedureEmailTemplatesConcern do
  describe 'mail templates' do
    subject { procedures.brouillon }

    it "returns expected classes" do
      expect(subject.email_depose_or_default).to be_a(Emails::Depose)
      expect(subject.email_passe_en_instruction_or_default).to be_a(Emails::PasseEnInstruction)
      expect(subject.email_accepte_or_default).to be_a(Emails::Accepte)
      expect(subject.email_refuse_or_default).to be_a(Emails::Refuse)
      expect(subject.email_classe_sans_suite_or_default).to be_a(Emails::ClasseSansSuite)
      expect(subject.email_repasse_en_instruction_or_default).to be_a(Emails::RepasseEnInstruction)
    end
  end

  describe '#send_combined_declarative_email?' do
    let(:procedure) { procedures.brouillon }

    it 'is false for a non declarative procedure' do
      expect(procedure.send_combined_declarative_email?).to be false
    end

    it 'is true for a declarative procedure by default' do
      procedure.declarative_with_state = :en_instruction

      expect(procedure.send_combined_declarative_email?).to be true
    end

    it 'is false for a declarative procedure kept on the legacy emails' do
      procedure.declarative_with_state = :en_instruction
      procedure.combined_declarative_email = false

      expect(procedure.send_combined_declarative_email?).to be false
    end
  end

  describe 'depose' do
    let(:procedure) { procedures.brouillon }

    subject { procedure }

    context 'when email_depose is not customize' do
      it { expect(subject.email_depose_or_default.body).to eq(Emails::Depose.default_for_procedure(procedure).body) }
    end

    context 'when email_depose is customize' do
      before :each do
        subject.email_depose = Emails::Depose.new(body: 'sisi')
        subject.save
        subject.reload
      end
      it { expect(subject.email_depose_or_default.body).to eq('sisi') }
    end

    context 'when email_depose is customize ... again' do
      before :each do
        subject.email_depose = Emails::Depose.new(body: 'toto')
        subject.save
        subject.reload
      end
      it do
        expect(subject.email_depose_or_default.body).to eq('toto')
        expect(Emails::Depose.where(procedure:).count).to eq(1)
      end
    end
  end

  describe 'closed mail template body' do
    let(:procedure) { procedures.brouillon.tap { it.update!(attestation_acceptation_template: attestation_template) } }
    let(:attestation_template) { nil }

    subject { procedure.email_accepte_or_default.body }

    context 'for procedures without an attestation' do
      it { is_expected.not_to include('lien attestation') }
    end

    context 'for procedures with an attestation' do
      let(:attestation_template) { build(:attestation_template, activated: activated) }

      context 'when the attestation is inactive' do
        let(:activated) { false }

        it { is_expected.not_to include('lien attestation') }
      end

      context 'when the attestation is inactive' do
        let(:activated) { true }

        it { is_expected.to include('lien attestation') }
      end
    end
  end

  describe 'refused mail template body' do
    let(:procedure) { procedures.brouillon.tap { it.update!(attestation_refus_template: attestation_template) } }
    let(:attestation_template) { nil }

    subject { procedure.email_refuse_or_default.body }

    context 'for procedures without an attestation' do
      it { is_expected.not_to include('lien attestation') }
    end

    context 'for procedures with an attestation' do
      let(:attestation_template) { build(:attestation_template, activated: activated, kind: 'refus') }

      context 'when the attestation is inactive' do
        let(:activated) { false }

        it { is_expected.not_to include('lien attestation') }
      end

      context 'when the attestation is inactive' do
        let(:activated) { true }

        it { is_expected.to include('lien attestation') }
      end
    end
  end

  describe '#email_template_attestation_inconsistency_state with email_accepte' do
    let(:procedure_without_attestation) { procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: nil) } }
    let(:procedure_with_active_attestation) do
      procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: build(:attestation_template, activated: true)) }
    end
    let(:procedure_with_inactive_attestation) do
      procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: build(:attestation_template, activated: false)) }
    end

    subject { procedure.email_template_attestation_inconsistency_state(:acceptation) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:email_accepte) { build(:email_accepte, body: '--lien attestation--') }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it do
            expect(subject).to eq(:extraneous_tag)
          end
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it do
            expect(subject).to eq(:extraneous_tag)
          end
        end
      end

      context 'that doesn’t contain a lien attestation tag' do
        let(:email_accepte) { build(:email_accepte) }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }

          it do
            expect(subject).to eq(:missing_tag)
          end
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }
          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#email_template_attestation_inconsistency_state with email_refuse' do
    let(:procedure_without_attestation) { procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: nil) } }
    let(:procedure_with_active_attestation) do
      procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: build(:attestation_template, activated: true, kind: 'refus')) }
    end
    let(:procedure_with_inactive_attestation) do
      procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: build(:attestation_template, activated: false, kind: 'refus')) }
    end

    subject { procedure.email_template_attestation_inconsistency_state(:refus) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:email_refuse) { build(:email_refuse, body: '--lien attestation--') }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it do
            expect(subject).to eq(:extraneous_tag)
          end
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it do
            expect(subject).to eq(:extraneous_tag)
          end
        end
      end

      context 'that doesn’t contain a lien attestation tag' do
        let(:email_refuse) { build(:email_refuse) }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }

          it do
            expect(subject).to eq(:missing_tag)
          end
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }
          it { is_expected.to be_nil }
        end
      end
    end
  end
end
