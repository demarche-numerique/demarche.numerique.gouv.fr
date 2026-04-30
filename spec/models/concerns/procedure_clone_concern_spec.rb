# frozen_string_literal: true

describe ProcedureCloneConcern, type: :model do
  describe 'clone' do
    let(:service) { create(:service) }
    let(:procedure) do
      create(:procedure,
        received_mail: received_mail,
        service: service,
        opendata: opendata,
        duree_conservation_etendue_par_ds: true,
        duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
        max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
        attestation_acceptation_template: build(:attestation_template, logo: logo, signature: signature),
        attestation_refus_template: build(:attestation_template, kind: 'refus'),
        types_de_champ_public:,
        types_de_champ_private:,
        api_particulier_token: '123456789012345',
        api_particulier_scopes: ['cnaf_famille'],
        estimated_dossiers_count: 4,
        template: true)
    end
    let(:types_de_champ_public) { [{}, {}, { type: :drop_down_list }, { type: :piece_justificative }, { type: :repetition, children: [{}] }] }
    let(:types_de_champ_private) { [{}, {}, { type: :drop_down_list }, { type: :repetition, children: [{}] }] }
    let(:type_de_champ_repetition) { procedure.draft_revision.types_de_champ_public.last }
    let(:type_de_champ_private_repetition) { procedure.draft_revision.types_de_champ_private.last }
    let(:received_mail) { build(:received_mail) }
    let(:from_library) { false }
    let(:opendata) { true }
    let(:administrateur) { procedure.administrateurs.first }
    let(:logo) { Rack::Test::UploadedFile.new('spec/fixtures/files/white.png', 'image/png') }
    let(:signature) { Rack::Test::UploadedFile.new('spec/fixtures/files/black.png', 'image/png') }

    let(:groupe_instructeur_1) { create(:groupe_instructeur, procedure: procedure, label: "groupe_1", contact_information: create(:contact_information)) }
    let(:instructeur_1) { create(:instructeur) }
    let(:instructeur_2) { create(:instructeur) }
    let!(:assign_to_1) { create(:assign_to, procedure: procedure, groupe_instructeur: groupe_instructeur_1, instructeur: instructeur_1) }
    let!(:assign_to_2) { create(:assign_to, procedure: procedure, groupe_instructeur: groupe_instructeur_1, instructeur: instructeur_2) }
    let(:options) do
      {
        clone_attestation_acceptation_template: true,
        clone_attestation_refus_template: true,
        cloned_from_library: from_library,
        clone_presentation: true,
        clone_instructeurs: true,
        clone_mail_templates: true,
        clone_champs: true,
        clone_annotations: true,
        clone_api_entreprise_token: true,
      }
    end

    subject do
      @procedure = procedure.clone(options:, admin: administrateur)
      @procedure.save
      @procedure
    end

    it { expect(subject.parent_procedure).to eq(procedure) }

    it 'the cloned procedure should not be a template anymore' do
      expect(subject.template).to be_falsey
    end

    describe "should keep groupe instructeurs " do
      it "should clone groupe instructeurs" do
        expect(subject.groupe_instructeurs.size).to eq(2)
        expect(subject.groupe_instructeurs.size).to eq(procedure.groupe_instructeurs.size)
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first).not_to be nil
        expect(subject.defaut_groupe_instructeur_id).to eq(subject.groupe_instructeurs.find_by(label: 'défaut').id)
      end

      it "should clone instructeurs in the groupe" do
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first.instructeurs.map(&:email)).to eq(procedure.groupe_instructeurs.where(label: "groupe_1").first.instructeurs.map(&:email))
      end

      it 'should clone with success a second group instructeur closed' do
        procedure.groupe_instructeurs.last.update(closed: true)

        expect { subject }.not_to raise_error
      end

      it 'should clone groupe instructeur services' do
        expect(procedure.groupe_instructeurs.last.contact_information).not_to eq nil
        expect(subject.groupe_instructeurs.last.contact_information).not_to eq nil
      end
    end

    it 'should reset duree_conservation_etendue_par_ds' do
      expect(subject.duree_conservation_etendue_par_ds).to eq(false)
      expect(subject.duree_conservation_dossiers_dans_ds).to eq(Expired::DEFAULT_DOSSIER_RENTENTION_IN_MONTH)
    end

    it 'should duplicate specific objects with different id' do
      expect(subject.id).not_to eq(procedure.id)

      expect(subject.draft_revision.types_de_champ_public.size).to eq(procedure.draft_revision.types_de_champ_public.size)
      expect(subject.draft_revision.types_de_champ_private.size).to eq(procedure.draft_revision.types_de_champ_private.size)

      procedure.draft_revision.types_de_champ_public.zip(subject.draft_revision.types_de_champ_public).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc)
        expect(stc.revisions).to include(subject.draft_revision)
      end

      public_repetition = type_de_champ_repetition
      cloned_public_repetition = subject.draft_revision.types_de_champ_public.find(&:repetition?)
      procedure.draft_revision.children_of(public_repetition).zip(subject.draft_revision.children_of(cloned_public_repetition)).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc)
        expect(stc.revisions).to include(subject.draft_revision)
      end

      procedure.draft_revision.types_de_champ_private.zip(subject.draft_revision.types_de_champ_private).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc)
        expect(stc.revisions).to include(subject.draft_revision)
      end

      private_repetition = type_de_champ_private_repetition
      cloned_private_repetition = subject.draft_revision.types_de_champ_private.find(&:repetition?)
      procedure.draft_revision.children_of(private_repetition).zip(subject.draft_revision.children_of(cloned_private_repetition)).each do |ptc, stc|
        expect(stc).to have_same_attributes_as(ptc)
        expect(stc.revisions).to include(subject.draft_revision)
      end

      expect(subject.attestation_acceptation_template.title).to eq(procedure.attestation_acceptation_template.title)
      expect(subject.attestation_refus_template.title).to eq(procedure.attestation_refus_template.title)

      expect(subject.cloned_from_library).to be(false)

      cloned_procedure = subject
      cloned_procedure.parent_procedure_id = nil
      expect(cloned_procedure).to have_same_attributes_as(procedure, except: [
        "path", "draft_revision_id", "service_id", 'estimated_dossiers_count',
        "duree_conservation_etendue_par_ds", "duree_conservation_dossiers_dans_ds", 'max_duree_conservation_dossiers_dans_ds',
        "defaut_groupe_instructeur_id", "template",
      ])
    end

    context 'when types_de_champ_public contains a referentiel' do
      let(:referentiel) { create(:api_referentiel, :exact_match, :with_exact_match_response, :with_authentication_data) }
      let(:stable_id) { 1337 }
      let(:types_de_champ_public) { [{ type: :referentiel, referentiel: referentiel, stable_id: }] }

      context 'when cloned by the same administrateur' do
        let(:administrateur) { procedure.administrateurs.first }

        it 'clones referentiel, does not reuse it' do
          expect { subject }.to change { Referentiel.count }.by(1)
        end

        it 'keeps API keys' do
          expect(subject.draft_revision.types_de_champ_public.first.referentiel.authentication_method).to eq(referentiel.authentication_method)
          expect(subject.draft_revision.types_de_champ_public.first.referentiel.authentication_data).to eq(referentiel.authentication_data)
        end
      end

      context 'when cloned by another administrateur' do
        let(:administrateur) { create(:administrateur) }

        it 'clones referentiel, does not reuse it' do
          expect { subject }.to change { Referentiel.count }.by(1)
        end

        it 'discards API keys' do
          expect(subject.draft_revision.types_de_champ_public.first.referentiel.authentication_data).to eq(nil)
        end
      end
    end

    context 'which is opendata' do
      let(:opendata) { false }
      it 'should keep opendata for same admin' do
        expect(subject.opendata).to be_falsy
      end
    end

    context 'when the procedure is cloned from the library' do
      let(:from_library) { true }

      it 'should set cloned_from_library to true' do
        expect(subject.cloned_from_library).to be(true)
      end

      it 'should set service_id to nil' do
        expect(subject.service).to eq(nil)
      end

      it 'should discard old pj information' do
        subject.draft_revision.types_de_champ_public.each do |stc|
          expect(stc.old_pj).to be_nil
        end
      end

      it 'should have one administrateur' do
        expect(subject.administrateurs).to eq([administrateur])
      end

      it 'should set ask_birthday to false' do
        expect(subject.ask_birthday?).to eq(false)
      end
    end

    context 'when the procedure is cloned from the library' do
      let(:procedure) { create(:procedure, received_mail: received_mail, service: service, ask_birthday: true) }

      it 'should set ask_birthday to false' do
        expect(subject.ask_birthday?).to eq(false)
      end
    end

    it 'should skips service_id' do
      expect(subject.service).to eq(nil)
    end

    context 'when the procedure is cloned to another administrateur' do
      let(:administrateur) { create(:administrateur) }
      let(:opendata) { false }

      context 'and the procedure does not have a groupe with the defaut label' do
        before do
          procedure.defaut_groupe_instructeur.update!(label: 'another label')
        end

        it "affects the first groupe as the defaut groupe" do
          expect(subject.defaut_groupe_instructeur).to eq(subject.groupe_instructeurs.first)
        end
      end

      it 'should not clone service' do
        expect(subject.service).to eq(nil)
      end

      context 'with groupe instructeur services' do
        it 'should not clone groupe instructeur services' do
          expect(procedure.groupe_instructeurs.last.contact_information).not_to eq nil
          expect(subject.groupe_instructeurs.last.contact_information).to eq nil
        end
      end

      it 'should discard old pj information' do
        subject.draft_revision.types_de_champ_public.each do |stc|
          expect(stc.old_pj).to be_nil
        end
      end

      it 'should discard specific api_entreprise_token' do
        expect(subject.read_attribute(:api_entreprise_token)).to be_nil
      end

      it 'should reset opendata to true' do
        expect(subject.opendata).to be_truthy
      end

      it 'should have one administrateur' do
        expect(subject.administrateurs).to eq([administrateur])
      end

      it "should discard the existing groupe instructeurs" do
        expect(subject.groupe_instructeurs.size).not_to eq(procedure.groupe_instructeurs.size)
        expect(subject.groupe_instructeurs.where(label: "groupe_1").first).to be nil
      end

      it "should discard api_particulier_scopes and token" do
        expect(subject.encrypted_api_particulier_token).to be_nil
        expect(subject.api_particulier_scopes).to be_empty
      end

      it 'should not route the procedure' do
        expect(subject.routing_enabled).to eq(false)
      end

      it 'should have a default groupe instructeur' do
        expect(subject.groupe_instructeurs.size).to eq(1)
        expect(subject.groupe_instructeurs.first.label).to eq(GroupeInstructeur::DEFAUT_LABEL)
        expect(subject.groupe_instructeurs.first.instructeurs.size).to eq(1)
      end
    end

    it 'should duplicate existing mail_templates' do
      expect(subject.received_mail.attributes.except("id", "procedure_id", "created_at", "updated_at")).to eq procedure.received_mail.attributes.except("id", "procedure_id", "created_at", "updated_at")
      expect(subject.received_mail.id).not_to eq procedure.received_mail.id
      expect(subject.received_mail.id).not_to be nil
      expect(subject.received_mail.procedure_id).not_to eq procedure.received_mail.procedure_id
      expect(subject.received_mail.procedure_id).not_to be nil
    end

    it 'should not duplicate default mail_template' do
      expect(subject.passer_en_construction_email_template.attributes).to eq Mails::InitiatedMail.default_for_procedure(subject).attributes
    end

    it 'should not duplicate specific related objects' do
      expect(subject.dossiers).to eq([])
    end

    it "should reset estimated_dossiers_count" do
      expect(subject.estimated_dossiers_count).to eq(0)
    end

    describe 'should not duplicate lien_notice' do
      let(:procedure) { create(:procedure, lien_notice: "http://toto.com") }

      it { expect(subject.lien_notice).to be_nil }
    end

    describe 'when a new attribute is added to Procedure' do
      it 'the developer should choose what to do with it when cloning' do
        # If this test fails, it is probably because you added an attribute to Procedure model.
        # If so, you have to decide what to do with this new attribute when a procedure is cloned.
        # More information in `app/models/concerns/procedure_clone_concern.rb`.
        expect(procedure.attributes.keys.to_set).to eq(Procedure::MANAGED_ATTRIBUTES.to_set)
      end
    end

    describe 'procedure status is reset' do
      let(:procedure) { create(:procedure, :closed, received_mail: received_mail, service: service, auto_archive_on: 3.weeks.from_now) }

      it 'Not published nor closed' do
        expect(subject.closed_at).to be_nil
        expect(subject.published_at).to be_nil
        expect(subject.unpublished_at).to be_nil
        expect(subject.auto_archive_on).to be_nil
        expect(subject.aasm_state).to eq "brouillon"
        expect(subject.path).not_to be_nil
      end
    end

    it 'should keep types_de_champ ids stable' do
      expect(subject.draft_revision.types_de_champ_public.first.id).not_to eq(procedure.draft_revision.types_de_champ_public.first.id)
      expect(subject.draft_revision.types_de_champ_public.first.stable_id).to eq(procedure.draft_revision.types_de_champ_public.first.id)
    end

    it 'should duplicate piece_justificative_template on a type_de_champ' do
      expect(subject.draft_revision.types_de_champ_public.find(&:piece_justificative?).piece_justificative_template.attached?).to be_truthy
    end

    context 'with a notice attached' do
      let(:procedure) { create(:procedure, :with_notice, received_mail: received_mail, service: service) }

      it 'should duplicate notice' do
        expect(subject.notice.attached?).to be_truthy
        expect(subject.notice.attachment).not_to eq(procedure.notice.attachment)
        expect(subject.notice.attachment.blob).to eq(procedure.notice.attachment.blob)

        subject.notice.attach(logo)
        subject.reload
        procedure.reload

        expect(subject.notice.attached?).to be_truthy
        expect(subject.notice.attachment.blob).not_to eq(procedure.notice.attachment.blob)

        subject.notice.purge
        subject.reload
        procedure.reload

        expect(subject.notice.attached?).to be_falsey
        expect(procedure.notice.attached?).to be_truthy
      end
    end

    context 'with a deliberation attached' do
      let(:procedure) { create(:procedure, :with_deliberation, received_mail: received_mail, service: service) }

      it 'should duplicate deliberation' do
        expect(subject.deliberation.attached?).to be true
      end
    end

    context 'with a default procedure_presentation active' do
      let(:procedure) { create(:procedure) }
      let(:procedure_presentation) { build(:procedure_presentation, assign_to: assign_to) }
      let(:instructeur) { create(:instructeur) }
      let(:assign_to) { create(:assign_to, procedure: procedure, instructeur: instructeur) }

      before do
        procedure.update!(
          admin_default_procedure_presentation_active: true,
          admin_default_procedure_presentation_id: procedure_presentation.id
        )
      end
      it 'should not clone default procedure_presentation attributes ' do
        expect(subject.admin_default_procedure_presentation_active).to be false
        expect(subject.admin_default_procedure_presentation_id).to be nil
      end
    end

    context 'with canonical procedure' do
      let(:canonical_procedure) { create(:procedure) }
      let(:procedure) { create(:procedure, canonical_procedure: canonical_procedure, received_mail: received_mail, service: service) }

      it 'do not clone canonical procedure' do
        expect(subject.canonical_procedure).to be_nil
      end
    end

    context 'with a drop_down_list referentiel' do
      let(:procedure) { create(:procedure, types_de_champ_public:, service:) }
      let(:types_de_champ_public) { [{ type: :drop_down_list, referentiel:, drop_down_mode: 'advanced' }] }
      let(:referentiel) { create(:csv_referentiel, :with_items) }
      let(:drop_down_list) { procedure.draft_revision.types_de_champ_public.first }
      let(:cloned_drop_down_list) { subject.draft_revision.types_de_champ_public.first }

      it {
        expect(cloned_drop_down_list.drop_down_mode).to eq('advanced')
        expect(cloned_drop_down_list.referentiel_id).to eq(referentiel.id)
        is_expected.to be_valid
      }
    end

    describe 'feature flag' do
      context 'with a feature flag enabled' do
        before do
          Flipper.enable(:dossier_pdf_vide, procedure)
        end

        it 'should enable feature' do
          expect(subject.feature_enabled?(:dossier_pdf_vide)).to be true
          expect(Flipper.feature(:dossier_pdf_vide).enabled_gate_names).to include(:actor)
        end
      end

      context 'with feature flag is fully enabled' do
        before do
          Flipper.enable(:dossier_pdf_vide)
        end

        it 'should not clone feature for actor' do
          expect(subject.feature_enabled?(:dossier_pdf_vide)).to be true
          expect(Flipper.feature(:dossier_pdf_vide).enabled_gate_names).not_to include(:actor)
        end
      end

      context 'with a feature flag enabled by percentage of actors' do
        before do
          Flipper.enable_percentage_of_actors(:dossier_pdf_vide, 50)
          Flipper.enable(:dossier_pdf_vide, procedure)
        end

        it 'should not clone actor gate for percentage-based feature' do
          expect(Flipper.feature(:dossier_pdf_vide).actors_value).not_to include(subject.flipper_id)
        end
      end

      context 'with a feature flag enabled by percentage of time' do
        before do
          Flipper.enable_percentage_of_time(:dossier_pdf_vide, 50)
          Flipper.enable(:dossier_pdf_vide, procedure)
        end

        it 'should not clone actor gate for percentage-based feature' do
          expect(Flipper.feature(:dossier_pdf_vide).actors_value).not_to include(subject.flipper_id)
        end
      end

      context 'with a feature flag disabled' do
        before do
          Flipper.disable(:dossier_pdf_vide, procedure)
        end

        it 'should not enable feature' do
          expect(subject.feature_enabled?(:dossier_pdf_vide)).to be false
        end
      end
    end
  end
end
