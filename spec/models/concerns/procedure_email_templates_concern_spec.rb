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

  describe '#legacy_declarative_emails?' do
    let(:procedure) { procedures.brouillon }

    it 'is false while the procedure sends the combined email' do
      procedure.update!(declarative_with_state: :en_instruction)

      expect(procedure.legacy_declarative_emails?).to be false
    end

    it 'is true once kept on the legacy emails' do
      procedure.update!(declarative_with_state: :en_instruction)
      procedure.update!(combined_declarative_email: false)

      expect(procedure.legacy_declarative_emails?).to be true
    end

    it 'is false for a non declarative procedure' do
      procedure.combined_declarative_email = false

      expect(procedure.legacy_declarative_emails?).to be false
    end
  end

  describe 'changing the declarative setting' do
    let(:procedure) { procedures.brouillon }

    before do
      procedure.update!(declarative_with_state: :en_instruction)
      procedure.update!(combined_declarative_email: false)
      create(:email_depose, procedure:)
      create(:email_refuse, procedure:)
      procedure.reload
    end

    it 'drops the depose template, keeps the others and moves to the combined email' do
      procedure.update!(declarative_with_state: :accepte)

      expect(procedure.reload.email_depose_templates).to be_empty
      expect(procedure.email_refuse).to be_present
      expect(procedure.combined_declarative_email).to be true
    end

    it 'drops it when the procedure stops being declarative' do
      procedure.update!(declarative_with_state: nil)

      expect(procedure.reload.email_depose_templates).to be_empty
      expect(procedure.email_refuse).to be_present
    end

    it 'keeps it when the declarative setting does not change' do
      procedure.update!(libelle: 'Un nouveau libellé')

      expect(procedure.reload.email_depose_templates).not_to be_empty
    end
  end

  describe '#email_depose_or_default' do
    let(:procedure) { procedures.brouillon }

    it 'defaults to the type of the declarative setting' do
      expect(procedure.email_depose_or_default).to be_an_instance_of(Emails::Depose)

      procedure.update!(declarative_with_state: :en_instruction)
      expect(procedure.email_depose_or_default).to be_an_instance_of(Emails::DeposeEtPasseEnInstruction)

      procedure.update!(declarative_with_state: :accepte)
      expect(procedure.email_depose_or_default).to be_an_instance_of(Emails::DeposeEtAccepte)
    end

    it 'ignores a customized template whose type no longer matches the setting' do
      procedure.update!(declarative_with_state: :accepte)
      create(:email_depose, procedure:)

      expect(procedure.reload.email_depose_or_default).to be_an_instance_of(Emails::DeposeEtAccepte)
      expect(procedure.email_depose_or_default).not_to be_persisted
    end

    it 'returns the customized template of the setting, even shadowed by a previous one' do
      procedure.update!(declarative_with_state: :accepte)
      create(:email_depose, procedure:)
      template = create(:email_depose_et_accepte, procedure:)

      expect(procedure.reload.email_depose_or_default).to eq(template)
    end

    it 'does not let a template left over by a previous setting block the publication' do
      procedure.update!(declarative_with_state: :accepte)
      create(:email_depose, procedure:).update_column(:body, '--balise inconnue--')

      expect(procedure.reload).to be_valid(:publication)
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

  describe '#attestation_tag_inconsistency with email_accepte' do
    let(:procedure_without_attestation) { procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: nil) } }
    let(:procedure_with_active_attestation) do
      procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: build(:attestation_template, activated: true)) }
    end
    let(:procedure_with_inactive_attestation) do
      procedures.brouillon.tap { it.update!(email_accepte: email_accepte, attestation_acceptation_template: build(:attestation_template, activated: false)) }
    end

    subject { procedure.attestation_tag_inconsistency(:acceptation) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:email_accepte) { build(:email_accepte, body: '--lien attestation--') }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it do
            expect(subject).to include(kind: :extraneous_tag)
          end
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it do
            expect(subject).to include(kind: :extraneous_tag)
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
            expect(subject).to include(kind: :missing_tag)
          end
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }
          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#attestation_tag_inconsistency with email_refuse' do
    let(:procedure_without_attestation) { procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: nil) } }
    let(:procedure_with_active_attestation) do
      procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: build(:attestation_template, activated: true, kind: 'refus')) }
    end
    let(:procedure_with_inactive_attestation) do
      procedures.brouillon.tap { it.update!(email_refuse: email_refuse, attestation_refus_template: build(:attestation_template, activated: false, kind: 'refus')) }
    end

    subject { procedure.attestation_tag_inconsistency(:refus) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:email_refuse) { build(:email_refuse, body: '--lien attestation--') }

        context 'when the procedure doesn’t have an attestation' do
          let(:procedure) { procedure_without_attestation }

          it do
            expect(subject).to include(kind: :extraneous_tag)
          end
        end

        context 'when the procedure has an active attestation' do
          let(:procedure) { procedure_with_active_attestation }
          it { is_expected.to be_nil }
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }

          it do
            expect(subject).to include(kind: :extraneous_tag)
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
            expect(subject).to include(kind: :missing_tag)
          end
        end

        context 'when the procedure has an inactive attestation' do
          let(:procedure) { procedure_with_inactive_attestation }
          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#attestation_tag_inconsistency with the combined declarative email' do
    let(:declarative_with_state) { :accepte }
    let(:attestation) { build(:attestation_template, activated: true) }
    let(:procedure) do
      procedures.brouillon.tap { it.update!(declarative_with_state:, attestation_acceptation_template: attestation) }.reload
    end

    subject { procedure.attestation_tag_inconsistency(:acceptation) }

    context 'when the combined template doesn’t contain a lien attestation tag' do
      before { create(:email_depose_et_accepte, procedure:, body: 'aucun tag ici') }

      it { is_expected.to include(kind: :missing_tag) }
    end

    context 'when only the accepte template contains a lien attestation tag' do
      before do
        create(:email_depose_et_accepte, procedure:, body: 'aucun tag ici')
        create(:email_accepte, procedure:, body: '--lien attestation--')
      end

      it { is_expected.to eq(email_slug: Emails::DeposeEtAccepte::SLUG, kind: :missing_tag) }
    end

    context 'when the procedure doesn’t have an attestation' do
      let(:attestation) { nil }

      before { create(:email_depose_et_accepte, procedure:, body: '--lien attestation--') }

      it { is_expected.to include(kind: :extraneous_tag) }
    end

    context 'when the declarative procedure only passes en instruction' do
      let(:declarative_with_state) { :en_instruction }

      before { create(:email_depose_et_passe_en_instruction, procedure:, body: 'aucun tag ici') }

      it { is_expected.to be_nil }
    end
  end

  describe '#email_templates' do
    def slugs(procedure) = procedure.email_templates.map { it.class.const_get(:SLUG) }

    it 'keeps the chronological order for a non declarative procedure' do
      expect(slugs(build(:procedure)))
        .to eq(%w[depose passe_en_instruction accepte refuse classe_sans_suite repasse_en_instruction])
    end

    it 'keeps the chronological order for a declarative procedure kept on the legacy emails' do
      expect(slugs(build(:procedure, declarative_with_state: :accepte, combined_declarative_email: false)))
        .to eq(%w[depose passe_en_instruction accepte refuse classe_sans_suite repasse_en_instruction])
    end

    it 'moves passe_en_instruction last for a declarative en_instruction procedure' do
      expect(slugs(build(:procedure, declarative_with_state: :en_instruction)))
        .to eq(%w[depose accepte refuse classe_sans_suite repasse_en_instruction passe_en_instruction])
    end

    it 'moves repasse_en_instruction second for a declarative accepte procedure' do
      expect(slugs(build(:procedure, declarative_with_state: :accepte)))
        .to eq(%w[depose repasse_en_instruction accepte refuse classe_sans_suite passe_en_instruction])
    end
  end
end
