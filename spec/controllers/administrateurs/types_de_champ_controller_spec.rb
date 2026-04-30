# frozen_string_literal: true

describe Administrateurs::TypesDeChampController, type: :controller do
  let(:procedure) do
    create(:procedure,
           types_de_champ_public: [
             { type: :integer_number, libelle: 'l1' },
             { type: :integer_number, libelle: 'l2' },
             { type: :drop_down_list, libelle: 'l3' },
           ],
           types_de_champ_private: [
             { type: :yes_no, libelle: 'bon dossier', private: true },
           ])
  end

  def first_coordinate = procedure.draft_revision.revision_types_de_champ_public.first
  def second_coordinate = procedure.draft_revision.reload.revision_types_de_champ_public.second
  def third_coordinate = procedure.draft_revision.revision_types_de_champ_public.third

  def extract_libelle(champ_component) = [champ_component.coordinate.libelle, champ_component.upper_coordinates.map(&:libelle)]

  def morpheds
    assigns(:morphed)
      .map { |component| extract_libelle(component) }.to_a
  end

  before { sign_in(procedure.administrateurs.first.user) }

  describe '#create' do
    let(:params) { default_params }

    let(:default_params) do
      {
        procedure_id: procedure.id,
        type_de_champ: {
          type_champ: type_champ,
          libelle: 'l1.5',
          after_stable_id: first_coordinate.stable_id,
        },
      }
    end

    subject { post :create, params: params, format: :turbo_stream }

    context "create type_de_champ text" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }

      # l1, l2, l3 => l1, l1.5, l2, l3
      # created: (l1.5, [l1]), morphed: (l2, [l1, l1.5]), (l3, [l1, l1.5, l2])
      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(nil)
        expect(assigns(:coordinate)).to eq(second_coordinate)
        expect(extract_libelle(assigns(:created))).to eq(['l1.5', ['l1']])
        expect(morpheds).to eq([['l2', ['l1', 'l1.5']], ['l3', ['l1', 'l1.5', 'l2']]])
      end
    end

    context "validate" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }
      let(:params) { default_params.deep_merge(type_de_champ: { type_champ: nil }) }

      it do
        is_expected.to have_http_status(:ok)
        expect(assigns(:coordinate)).to be_nil
        expect(flash.alert).to eq(["Le champ « Type champ » doit être rempli"])
      end
    end
  end

  describe '#update' do
    let(:params) { default_params }
    let(:default_params) do
      {
        procedure_id: procedure.id,
        stable_id: second_coordinate.stable_id,
        type_de_champ: {
          libelle: 'updated',
        },
      }
    end

    subject { post :update, params: params, format: :turbo_stream }

    # l1, l2, l3 => l1, updated, l3
    # morphed: (updated, [l1]), (l3, [l1, updated])
    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(second_coordinate.libelle).to eq('updated')

      expect(assigns(:coordinate)).to eq(second_coordinate)
      expect(morpheds).to eq([['updated', ['l1']], ['l3', ['l1', 'updated']]])
    end

    context "validate" do
      let(:params) { default_params.deep_merge(type_de_champ: { libelle: '' }) }

      it do
        is_expected.to have_http_status(:ok)
        expect(assigns(:coordinate)).to eq(second_coordinate)
        expect(flash.alert).to be_nil
      end
    end

    context 'rejected if type changed and routing involved' do
      let(:params) do
        default_params.deep_merge(type_de_champ: { type_champ: 'text', stable_id: third_coordinate.stable_id })
      end

      before do
        allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to include("utilisé pour le routage")
      end
    end

    context 'rejected if type changed and referentiel url involved' do
      let(:params) do
        default_params.deep_merge(type_de_champ: { type_champ: 'text', stable_id: third_coordinate.stable_id })
      end

      before do
        allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_referentiel_urls?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to include("utilisé par un référentiel")
      end
    end

    context 'with a dropdown list with a referentiel' do
      let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }
      let(:drop_down_list_type_de_champ) do
        procedure.draft_revision.types_de_champ_public.third
      end

      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: third_coordinate.stable_id,
          referentiel_file:,
          name: referentiel_file.original_filename,
          type_de_champ: {
            libelle: 'updated',
          },
        }
      end

      context 'working case with multi column file' do
        it 'creates a valid referentiel' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(3)
          expect(drop_down_list_type_de_champ.reload.referentiel).to eq Referentiel.last
          expect(Referentiel.last.types_de_champ).to eq [drop_down_list_type_de_champ]
          expect(Referentiel.last.name).to eq referentiel_file.original_filename
          expect(Referentiel.last.type).to eq 'Referentiels::CsvReferentiel'
          expect(ReferentielItem.first.data).to eq({ "row" => { "calorie_kcal" => "145", "dessert" => "Éclair au café", "poids_g" => "60" } })
          expect(ReferentielItem.first.referentiel_id).to eq(Referentiel.last.id)
        end
      end

      context 'working case with uniq column file' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-one-column-referentiel.csv', 'text/csv') }

        it 'creates a valid referentiel' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(3)
          expect(ReferentielItem.first.data).to eq({ "row" => { "dessert" => "Éclair au café" } })
        end
      end

      context 'when the csv file length is more than 10 mo' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }

        before do
          allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(11.megabytes)
          subject
        end

        it 'verifies the file size limitation' do
          expect(flash.alert).to be_present
          expect(flash.alert).to eq("Importation impossible : le poids du fichier est supérieur à 1 Mo")
        end
      end

      context 'when the file content type is not accepted' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/french-flag.gif', 'image/gif') }

        before { subject }

        it 'checks file format acceptance' do
          expect(flash.alert).to be_present
          expect(flash.alert).to eq("Importation impossible : veuillez importer un fichier CSV")
        end
      end

      context 'when the csv file has a bom' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel-with-bom.csv', 'text/csv') }

        it 'creates a valid referentiel' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(13)
          expect(ReferentielItem.first.data).to eq({ "row" => { "description" => "Direction des Affaires financières et sociales", "flex_value" => "AFS" } })
        end
      end

      context 'when the csv file has no separators' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel-without-separators.csv', 'text/csv') }
        before { subject }

        it 'catches smarter csv error' do
          expect(flash.alert).to be_present
          expect(flash.alert).to eq("Importation impossible : le fichier est vide ou mal interprété")
        end
      end

      context 'when the csv file is iso-8859 format, with CRLF line terminators and special characters (even in header)' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel-iso-8859-crlf-special-characters.csv', 'text/csv') }
        it 'works' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(2)
          expect(ReferentielItem.first.data).to eq({ "row" => { "adresse" => "115, Boulevard Exelmans, Paris, 75016", "email" => "moha.ali@diplomatie.gouv.fr", "nom" => "Mohamed Ali", "numero" => "UK +447 864 743 320" } })
          expect(Referentiel.first.headers).to eq(["adresse", "nom", "numéro", "email"])
        end
      end

      context 'when SmarterCSV returns symbol keys (edge case)' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }
        let(:csv_content_with_symbol_keys) do
          [
            { :dessert => "60" },
          ]
        end

        before do
          # Simulate what happens when SmarterCSV returns Symbol keys as headers
          # This can happen with certain SmarterCSV versions or edge cases (https://demarches-simplifiees.sentry.io/issues/6969132983/events/a1516d5564ca4b9a87ed74921c8c470e/?project=1429550)
          allow_any_instance_of(Administrateurs::TypesDeChampController).to receive(:parse_csv).and_return(csv_content_with_symbol_keys)
        end

        it 'should work' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(1)
          expect(ReferentielItem.first.data).to eq({ "row" => { "dessert" => "60" } })
        end
      end
    end

    context 'with a multiple dropdown list with a referentiel' do
      let(:procedure) do
        create(:procedure,
               types_de_champ_public: [
                 { type: :multiple_drop_down_list, libelle: 'l1' },
               ])
      end
      let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }
      let(:multiple_drop_down_list_type_de_champ) do
        procedure.draft_revision.types_de_champ_public.first
      end
      let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }

      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: coordinate.stable_id,
          referentiel_file:,
          name: referentiel_file.original_filename,
          type_de_champ: {
            libelle: 'updated',
          },
        }
      end

      context 'working case with multi column file' do
        it 'creates a valid referentiel' do
          expect { subject }.to change(Referentiel, :count).by(1).and change(ReferentielItem, :count).by(3)
          expect(multiple_drop_down_list_type_de_champ.reload.referentiel).to eq Referentiel.last
          expect(Referentiel.last.types_de_champ).to eq [multiple_drop_down_list_type_de_champ]
          expect(Referentiel.last.name).to eq referentiel_file.original_filename
          expect(Referentiel.last.type).to eq 'Referentiels::CsvReferentiel'
          expect(ReferentielItem.first.data).to eq({ "row" => { "calorie_kcal" => "145", "dessert" => "Éclair au café", "poids_g" => "60" } })
          expect(ReferentielItem.first.referentiel_id).to eq(Referentiel.last.id)
        end
      end
    end
  end

  # l1, l2, l3 => l1, l3, l2
  # destroyed: l3, created: (l3, [l1]), morphed: (l2, [l1, l3])
  describe '#move_up' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: third_coordinate.stable_id }
    end

    subject { patch :move_up, params: params, format: :turbo_stream }

    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(second_coordinate.libelle).to eq('l3')
      expect(assigns(:coordinate)).to eq(second_coordinate)
      expect(assigns(:destroyed).libelle).to eq('l3')
      expect(extract_libelle(assigns(:created))).to eq(['l3', ['l1']])
      expect(morpheds).to eq([['l2', ['l1', 'l3']]])
    end
  end

  # l1, l2, l3 => l2, l1, l3
  # destroyed: l1, created: (l1, [l2]), morphed: (l2, [])
  describe '#move_down' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: first_coordinate.stable_id }
    end

    subject { patch :move_down, params: params, format: :turbo_stream }

    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)

      expect(assigns(:coordinate)).to eq(second_coordinate)
      expect(assigns(:destroyed).libelle).to eq('l1')
      expect(extract_libelle(assigns(:created))).to eq(['l1', ['l2']])
      expect(morpheds).to eq([['l2', []]])
    end
  end

  describe '#move_and_morph' do
    # l1, l2, l3 => l2, l3, l1
    context 'move and morph down' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: first_coordinate.stable_id, target_stable_id: third_coordinate.stable_id }
      end

      subject { patch :move_and_morph, params: params, format: :turbo_stream }

      it do
        is_expected.to have_http_status(:ok)
        expect(assigns(:coordinate)).to eq(first_coordinate)
        expect(assigns(:destroyed)).to eq(first_coordinate)
        expect(extract_libelle(assigns(:created))).to eq(['l1', ['l2', 'l3']])
        expect(morpheds).to eq([['l2', []], ['l3', ['l2']]])
      end
    end

    # l1, l2, l3 => l1, l3, l2
    context 'move and morph up' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_coordinate.stable_id, target_stable_id: first_coordinate.stable_id }
      end

      subject { patch :move_and_morph, params: params, format: :turbo_stream }

      it do
        is_expected.to have_http_status(:ok)
        [first_coordinate, second_coordinate, third_coordinate].map(&:reload)
        expect(assigns(:coordinate).stable_id).to eq(second_coordinate.stable_id)
        expect(assigns(:destroyed).stable_id).to eq(second_coordinate.stable_id)
        expect(extract_libelle(assigns(:created))).to eq(['l3', ['l1']])
        expect(morpheds).to eq([['l3', ['l1']], ['l2', ['l1', 'l3']]])
      end
    end
  end

  # l1, l2, l3 => l1, l3
  # destroyed: l2, morphed: (l3, [l1])
  describe '#destroy' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: second_coordinate.stable_id }
    end

    subject { delete :destroy, params: params, format: :turbo_stream }

    it do
      used_to_be_second_coordinate = second_coordinate

      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(assigns(:coordinate)).to eq(used_to_be_second_coordinate)
      expect(assigns(:destroyed).libelle).to eq('l2')
      expect(morpheds).to eq([['l3', ['l1']]])
    end

    context 'rejected if type changed and routing involved' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_coordinate.stable_id }
      end

      before do
        allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to include("utilisé pour le routage")
      end
    end

    context 'rejected if referentiel url involved' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_coordinate.stable_id }
      end

      before do
        allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_referentiel_urls?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to include("utilisé par un référentiel")
      end
    end
  end

  describe '#notice_explicative' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :explication }]) }
    let(:coordinate) { procedure.draft_revision.types_de_champ.first }
    let(:file) { Tempfile.new }
    let(:blob) { ActiveStorage::Blob.create_before_direct_upload!(filename: File.basename(file.path), byte_size: file.size, checksum: Digest::SHA256.file(file.path), content_type: 'text/plain') }

    context 'when sending a valid blob' do
      it 'attaches the blob and responds with 200' do
        expect { put :notice_explicative, format: :turbo_stream, params: { stable_id: coordinate.stable_id, procedure_id: procedure.id, blob_signed_id: blob.signed_id } }
          .to change { coordinate.reload.notice_explicative.attached? }
          .from(false).to(true)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe '#nullify_referentiel' do
    let(:procedure) { create(:procedure) }
    let!(:type_de_champ) { create(:type_de_champ_drop_down_list, procedure:, referentiel:) }
    let(:referentiel) { create(:csv_referentiel, :with_items) }

    let(:params) do
      { procedure_id: procedure.id, stable_id: type_de_champ.stable_id }
    end

    subject { delete :nullify_referentiel, params: params, format: :turbo_stream }

    context 'working case with multi column file' do
      it 'nullifies referentiel' do
        expect { subject }.to not_change(Referentiel, :count).and not_change(ReferentielItem, :count)
        expect(type_de_champ.reload.referentiel).to be_nil
        expect(Referentiel.count).to eq 1
        expect(ReferentielItem.count).to eq 3
      end
    end
  end

  describe '#simplify' do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :text, libelle: 'Ancien', stable_id: 123 }] }
    let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
    let(:tunnel_id) { SecureRandom.hex(3) }
    let(:procedure_revision) { procedure.draft_revision }
    let(:schema_hash) { Digest::SHA256.hexdigest(procedure_revision.schema_to_llm.to_json) }
    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }
    subject { get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: llm_rule_suggestion.rule } }

    context 'without LLM Suggestion' do
      # Create a suggestion for a different rule to establish the tunnel
      let!(:tunnel_seed) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, rule: 'improve_structure', state: 'accepted', schema_hash:) }
      let(:llm_rule_suggestion) { double(rule:) }
      it 'builds a new LLMRuleSuggestion when none exists' do
        expect(subject).to have_http_status(:ok)
        expect(assigns(:llm_rule_suggestion)).to be_an_instance_of(LLMRuleSuggestion)
      end
    end

    context 'with queued suggestion' do
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'queued', rule: rule) }

      it 'renders' do
        expect(subject).to have_http_status(:ok)
      end
    end

    context 'with running llm suggestion' do
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'running', rule: rule) }
      it 'renders' do
        expect(subject).to have_http_status(:ok)
      end
    end

    context 'with existing ready suggestion' do
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'completed', rule: rule) }

      it 'assigns label suggestions from stored LLMRuleSuggestion items' do
        expect(subject).to have_http_status(:ok)
        expect(assigns(:llm_rule_suggestion)).to eq(llm_rule_suggestion)
      end
    end

    context 'with accepted suggestion' do
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'accepted', rule: rule) }

      it 'redirects to next step when visiting accepted suggestion' do
        expect(subject).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: LLM::Rule.next_rule(rule)))
      end
    end

    context 'when accepted suggestion is the last one, render the form' do
      let!(:first_accepted_rule) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'accepted', rule: LLMRuleSuggestion.rules.keys.first, created_at: 1.minute.ago) }
      let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'accepted', rule: LLMRuleSuggestion.rules.keys.last) }

      it 'renders the procedure form' do
        expect(subject).to have_http_status(:ok)
      end
    end

    context 'when tunnel completed, visiting an accepted step' do
      let!(:first_accepted_rule) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'accepted', rule: LLMRuleSuggestion.rules.keys.first, created_at: 2.minutes.ago) }
      let!(:last_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision:, tunnel_id:, schema_hash:, state: 'accepted', rule: LLMRuleSuggestion.rules.keys.last, created_at: 1.minute.ago) }
      let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
      subject { get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: } }

      it 'redirects to last step when visiting first accepted step' do
        subject
        expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: LLMRuleSuggestion.rules.keys.last))
      end
    end
  end

  describe '#enqueue_simplify' do
    let(:procedure) { create(:procedure, :published) }
    let(:schema_hash) { Digest::SHA256.hexdigest(procedure.draft_revision.schema_to_llm.to_json) }
    let(:tunnel_id) { SecureRandom.hex(3) }

    before {
      Flipper.enable_actor(:llm_nightly_improve_procedure, procedure)
      # Create a suggestion with different rule in the tunnel so ensure_valid_tunnel passes
      # This simulates that the tunnel already exists from a previous step
      create(:llm_rule_suggestion,
        procedure_revision: procedure.draft_revision,
        tunnel_id:,
        rule: LLMRuleSuggestion.rules.fetch('improve_structure'),
        state: 'accepted',
        schema_hash:)
    }
    let(:rule) { LLMRuleSuggestion.rules.fetch('improve_label') }
    subject { post :enqueue_simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: } }

    it 'enqueues the improve procedure job when no analysis is running' do
      expect(LLM::ImproveProcedureJob).to receive(:perform_now).with(procedure, tunnel_id, rule, action: 'enqueue_simplify', user_id: procedure.administrateurs.first.user.id)

      expect(subject).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule:))
      expect(flash[:notice]).to be_present
    end

    it 'does not enqueue when analysis already running' do
      create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule:, state: 'queued', schema_hash:)
      expect(LLM::ImproveProcedureJob).not_to receive(:perform_now)

      expect(subject).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule:))
      expect(flash[:notice]).to eq('Une recherche est déjà en cours pour cette règle.')
    end

    it 'does not enqueue when feature disabled' do
      Flipper.disable_actor(:llm_nightly_improve_procedure, procedure)
      expect(LLM::ImproveProcedureJob).not_to receive(:perform_now)

      expect(subject).to redirect_to(admin_procedure_path(procedure))
      expect(flash[:alert]).to eq('Les appels aux modèles de langage ne sont pas activés pour cette procédure.')
    end

    it 're-enqueues after a failure' do
      create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule:, state: 'failed', schema_hash:)
      expect(LLM::ImproveProcedureJob).to receive(:perform_now).with(procedure, tunnel_id, rule, action: 'enqueue_simplify', user_id: procedure.administrateurs.first.user.id)

      subject

      expect(flash[:notice]).to be_present
    end
  end

  describe '#accept_simplification' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:types_de_champ_public) do
      [
        { type: :text, libelle: 'A', stable_id: 123 },
        { type: :text, libelle: 'B' },
      ]
    end
    let(:tunnel_id) { SecureRandom.hex(3) }
    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }
    subject do
      post :accept_simplification, params: {
        procedure_id: procedure.id,
        tunnel_id:,
        rule: suggestion.rule,
        id: suggestion.id,
        llm_rule_suggestion: {
          llm_rule_suggestion_items_attributes: {
            "0" => { id: accepted_suggestion_item.id, verify_status: 'accepted' },
            "1" => { id: skipped_suggestion_item.id, verify_status: 'skipped' },
          },
        },
      }
    end
    let(:suggestion) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule: 'improve_label', state: 'completed', schema_hash: Digest::SHA256.hexdigest(procedure.published_revision.schema_to_llm.to_json)) }
    let(:accepted_suggestion_item) { create(:llm_rule_suggestion_item, llm_rule_suggestion: suggestion, op_kind: 'update', stable_id: 123, payload: { 'stable_id' => 123, 'libelle' => 'Nouveau' }, justification: 'clarity') }
    let(:skipped_suggestion_item) { create(:llm_rule_suggestion_item, llm_rule_suggestion: suggestion, op_kind: 'update', stable_id: 123, payload: { 'stable_id' => 123, 'libelle' => 'Nouveau' }, justification: 'clarity') }

    it 'applies only selected operations from posted changes_json' do
      expect { subject }.to change { suggestion.reload.state }.from('completed').to('accepted')
      expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'improve_structure'))

      libelles = procedure.draft_revision.reload.types_de_champ_public.map(&:libelle)
      expect(libelles).to include('Nouveau')
      expect(libelles).not_to include('A')

      expect(accepted_suggestion_item.reload.verify_status).to eq('accepted')
      expect(accepted_suggestion_item.applied_at).not_to be_nil
      expect(skipped_suggestion_item.reload.verify_status).to eq('skipped')
      expect(skipped_suggestion_item.reload.applied_at).to be_nil
    end

    context 'when suggestion has no items' do
      let(:accepted_suggestion_item) { nil }
      let(:skipped_suggestion_item) { nil }

      subject do
        post :accept_simplification, params: {
          procedure_id: procedure.id,
          tunnel_id:,
          rule: suggestion.rule,
          id: suggestion.id,
        }
      end

      it 'transitions state from completed to skipped and redirect' do
        expect { subject }.to change { suggestion.reload.state }.from('completed').to('skipped')
        expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'improve_structure'))
      end
    end

    context 'when accepting the last step (cleaner)' do
      let(:initial_schema_hash) { Digest::SHA256.hexdigest(procedure.draft_revision.schema_to_llm.to_json) }

      # Create all 4 suggestions for the tunnel
      let!(:step1) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule: 'improve_label', state: 'accepted', schema_hash: initial_schema_hash) }
      let!(:step2) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule: 'improve_structure', state: 'accepted', schema_hash: initial_schema_hash) }
      let!(:step3) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule: 'improve_types', state: 'accepted', schema_hash: initial_schema_hash) }
      let(:suggestion) { create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision, tunnel_id:, rule: 'cleaner', state: 'completed', schema_hash: initial_schema_hash) }
      let(:accepted_suggestion_item) { nil }
      let(:skipped_suggestion_item) { nil }

      subject do
        post :accept_simplification, params: {
          procedure_id: procedure.id,
          tunnel_id:,
          rule: suggestion.rule,
          id: suggestion.id,
        }
      end

      it 'redirects to cleaner page with completion message' do
        expect { subject }.to change { suggestion.reload.state }.from('completed').to('skipped')
        expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'cleaner'))
        expect(flash[:notice]).to include("Toutes les suggestions ont été examinées")
      end
    end
  end

  describe 'Simpliscore tunnel flow' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: 'Champ A', stable_id: 100 }]) }
    let(:draft) { procedure.draft_revision }
    let(:initial_schema_hash) { Digest::SHA256.hexdigest(draft.schema_to_llm.to_json) }
    let(:tunnel_id) { SecureRandom.hex(3) }

    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }

    def current_schema_hash
      Digest::SHA256.hexdigest(draft.reload.schema_to_llm.to_json)
    end

    def change_schema!
      draft.add_type_de_champ(type_champ: 'text', libelle: "Nouveau champ #{SecureRandom.hex(4)}")
    end

    describe '#simplify tunnel continuation' do
      # OBSOLETE: Schema change mid-tunnel no longer triggers automatic suggestion renewal
      context 'when schema changes mid-tunnel after accepting step 1' do
        let!(:step1_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_label',
            state: 'accepted',
            schema_hash: initial_schema_hash)
        end

        before { change_schema! }

        it 'allows accessing step 2 after schema changed' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_structure' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion)).not_to be_persisted
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
        end

        it 'creates step 2 suggestion with new schema_hash' do
          expect {
            post :enqueue_simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_structure' }
          }.to change(LLMRuleSuggestion, :count).by(1)

          new_suggestion = LLMRuleSuggestion.last
          expect(new_suggestion.schema_hash).to eq(current_schema_hash)
        end
      end

      context 'when accessing cleaner (last step) while tunnel is in progress and schema changed' do
        let!(:step1_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_label',
            state: 'accepted',
            schema_hash: initial_schema_hash)
        end
        let!(:step2_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_structure',
            state: 'accepted',
            schema_hash: initial_schema_hash)
        end
        let!(:step3_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_types',
            state: 'accepted',
            schema_hash: initial_schema_hash)
        end
        let!(:cleaner_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'cleaner',
            state: 'completed',
            schema_hash: initial_schema_hash)
        end

        before { change_schema! }

        it 'allows accessing cleaner step (tunnel not finished yet)' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'cleaner' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion)).not_to be_persisted
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
        end
      end
    end

    describe '#simplify tunnel restart when schema changed' do
      context 'when tunnel is complete and schema has changed' do
        let!(:suggestions) do
          LLMRuleSuggestion::RULE_SEQUENCE.map do |rule|
            create(:llm_rule_suggestion,
              procedure_revision: draft,
              tunnel_id:,
              rule: rule,
              state: 'accepted',
              schema_hash: initial_schema_hash)
          end
        end

        before { change_schema! }

        it 'allows starting a new tunnel on step 1' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion)).not_to be_persisted
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
        end
      end
    end

    describe '#simplify no restart when schema unchanged' do
      context 'when tunnel is complete but schema has NOT changed' do
        let!(:suggestions) do
          LLMRuleSuggestion::RULE_SEQUENCE.map do |rule|
            create(:llm_rule_suggestion,
              procedure_revision: draft,
              tunnel_id:,
              rule: rule,
              state: 'accepted',
              schema_hash: initial_schema_hash)
          end
        end

        it 'redirects to last step (cleaner) when visiting step 1 (already finished)' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }

          # Devrait rediriger vers cleaner (dernière étape)
          expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'cleaner'))
        end

        it 'does not create new suggestion when enqueuing step 1 (job detects duplicate)' do
          expect {
            post :enqueue_simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }
          }.not_to change(LLMRuleSuggestion, :count)

          # Note: Controller triggers the job but job returns early when it detects existing suggestion
          expect(flash[:notice]).to eq('La recherche a été lancée. Vous serez prévenu(e) lorsque les suggestions seront prêtes.')
        end
      end
    end
  end

  describe 'Simpliscore tunnel flow' do
    let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :text, libelle: 'Champ A', stable_id: 100 }]) }
    let(:draft) { procedure.draft_revision }
    let(:initial_schema_hash) { Digest::SHA256.hexdigest(draft.schema_to_llm.to_json) }
    let(:tunnel_id) { SecureRandom.hex(3) }

    before { Flipper.enable_actor(:llm_nightly_improve_procedure, procedure) }

    def current_schema_hash
      Digest::SHA256.hexdigest(draft.reload.schema_to_llm.to_json)
    end

    def change_schema!
      draft.add_type_de_champ(type_champ: 'text', libelle: "Nouveau champ #{SecureRandom.hex(4)}")
    end

    describe '#simplify tunnel continuation' do
      context 'when schema changes mid-tunnel after accepting step 1' do
        let!(:step1_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_label',
            state: 'accepted',
            schema_hash: initial_schema_hash)
        end

        before { change_schema! }

        it 'allows accessing step 2 after schema changed' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_structure' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion)).not_to be_persisted
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
        end

        it 'creates step 2 suggestion with current schema_hash' do
          expect {
            post :enqueue_simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_structure' }
          }.to change(LLMRuleSuggestion, :count).by(1)

          new_suggestion = LLMRuleSuggestion.last
          expect(new_suggestion.schema_hash).to eq(current_schema_hash)
        end
      end

      context 'when accessing cleaner (last step) while tunnel is in progress and schema changed' do
        let!(:step1_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_label',
            state: 'accepted',
            schema_hash: initial_schema_hash,
            created_at: 3.minutes.ago)
        end
        let!(:step2_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_structure',
            state: 'accepted',
            schema_hash: initial_schema_hash + "2",
            created_at: 2.minutes.ago)
        end
        let!(:step3_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'improve_types',
            state: 'accepted',
            schema_hash: initial_schema_hash + "3",
            created_at: 1.minute.ago)
        end
        let!(:cleaner_suggestion) do
          create(:llm_rule_suggestion,
            procedure_revision: draft,
            tunnel_id:,
            rule: 'cleaner',
            state: 'completed',
            schema_hash: initial_schema_hash + "4")
        end

        before { change_schema! }

        it 'allows accessing cleaner step (tunnel not finished yet) and renew suggestion' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'cleaner' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion)).not_to be_persisted
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
          expect(assigns(:llm_rule_suggestion)).not_to eq(cleaner_suggestion)
        end
      end
    end

    describe '#simplify tunnel restart when schema changed (duplicate test)' do
      context 'when tunnel is complete and schema has changed' do
        let!(:suggestions) do
          LLMRuleSuggestion::RULE_SEQUENCE.map do |rule|
            create(:llm_rule_suggestion,
              procedure_revision: draft,
              tunnel_id:,
              rule: rule,
              state: 'accepted',
              schema_hash: initial_schema_hash)
          end
        end

        before { change_schema! }

        it 'allows starting a new tunnel on step 1' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }

          expect(response).to have_http_status(:ok)
          expect(assigns(:llm_rule_suggestion).rule).to eq('improve_label')
          expect(assigns(:llm_rule_suggestion).schema_hash).to eq(current_schema_hash)
          expect(response).not_to be_redirect
        end
      end
    end

    describe '#simplify' do
      # Groupe 8: Tunnel en cours (steps 1-3 accepted), visite step 1 → redirige vers cleaner
      context 'when tunnel is ongoing' do
        let!(:suggestions) do
          LLMRuleSuggestion::RULE_SEQUENCE.take(3).reverse.map.with_index do |rule, index|
            create(:llm_rule_suggestion,
              procedure_revision: draft,
              tunnel_id:,
              rule: rule,
              state: 'accepted',
              schema_hash: initial_schema_hash,
              created_at: (index + 1).minutes.ago)
          end
        end

        it 'redirects from first step (already finished) to next incomplete step' do
          get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }

          expect(response).to redirect_to(simplify_admin_procedure_types_de_champ_path(procedure, tunnel_id:, rule: 'cleaner'))
        end
      end
    end
  end
end
