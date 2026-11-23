# frozen_string_literal: true

describe Administrateurs::TypesDeChampController, type: :controller do
  let(:procedure) do
    create(:procedure,
           public_type_de_champs: [
             { type: :integer_number, libelle: 'l1' },
             { type: :integer_number, libelle: 'l2' },
             { type: :drop_down_list, libelle: 'l3' },
           ],
           private_type_de_champs: [
             { type: :yes_no, libelle: 'bon dossier', private: true },
           ])
  end

  def first_type_de_champ = procedure.draft_revision.reload.public_type_de_champs.first
  def second_type_de_champ = procedure.draft_revision.reload.public_type_de_champs.second
  def third_type_de_champ = procedure.draft_revision.reload.public_type_de_champs.third

  # what the stream brings up to date: the block edited, the list items it
  # removes and inserts, the cards it renders again
  def siblings = assigns(:type_de_champs)&.map(&:libelle)
  def libelles(stable_ids) = TypeDeChamp.where(procedure:, stable_id: stable_ids).pluck(:stable_id, :libelle).to_h.values_at(*stable_ids)
  def removed = libelles(assigns(:changes).removed)
  def inserted = libelles(assigns(:changes).inserted)
  def cards = libelles(assigns(:changes).cards)

  before { sign_in(procedure.administrateurs.first.user) }

  describe 'unauthenticated access' do
    before { sign_out(procedure.administrateurs.first.user) }

    it 'redirects to sign in instead of raising' do
      get :new_simplify, params: { procedure_id: procedure.id }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe '#create' do
    let(:params) { default_params }

    let(:default_params) do
      {
        procedure_id: procedure.id,
        type_de_champ: {
          type_champ: type_champ,
          libelle: 'l1.5',
          after_stable_id: first_type_de_champ.stable_id,
        },
      }
    end

    subject { post :create, params: params, format: :turbo_stream }

    context "create type_de_champ text" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }

      # l1, l2, l3 => l1, l1.5, l2, l3
      # inserted: l1.5, cards: l2 and l3, which sit further
      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(nil)
        expect(siblings).to eq(['l1', 'l1.5', 'l2', 'l3'])
        expect(removed).to be_empty
        expect(inserted).to eq(['l1.5'])
        expect(cards).to eq(['l2', 'l3'])
        expect(assigns(:focused).libelle).to eq('l1.5')
      end
    end

    context "rendering the stream" do
      render_views
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }

      it "leaves the page breadcrumb alone" do
        subject
        expect(response.body).not_to have_css("turbo-stream[target='breadcrumbs']")
      end
    end

    context 'with a type which does not exist' do
      let(:type_champ) { 'unknown' }

      it do
        is_expected.to have_http_status(:ok)
        expect(siblings).to be_nil
        expect(flash.alert).to eq(["Ce type de champ n’existe pas."])
      end
    end

    context "validate" do
      let(:type_champ) { TypeDeChamp.type_champs.fetch(:text) }
      let(:params) { default_params.deep_merge(type_de_champ: { type_champ: nil }) }

      it do
        is_expected.to have_http_status(:ok)
        expect(siblings).to be_nil
        expect(flash.alert).to eq(["Le champ « Type champ » doit être rempli"])
      end
    end
  end

  describe '#update' do
    let(:params) { default_params }
    let(:default_params) do
      {
        procedure_id: procedure.id,
        stable_id: second_type_de_champ.stable_id,
        type_de_champ: {
          libelle: 'updated',
        },
      }
    end

    subject { post :update, params: params, format: :turbo_stream }

    # l1, l2, l3 => l1, updated, l3
    # cards: updated, and l3 whose condition may read it
    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(second_type_de_champ.libelle).to eq('updated')

      expect(siblings).to eq(['l1', 'updated', 'l3'])
      expect([removed, inserted]).to all(be_empty)
      expect(cards).to eq(['updated', 'l3'])
    end

    context 'with repetitions around' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { type: :repetition, libelle: 'before', children: [{ libelle: 'b1' }] },
          { libelle: 'l2' },
          { type: :repetition, libelle: 'after', children: [{ libelle: 'a1' }, { libelle: 'a2' }] },
        ])
      end

      render_views

      def cards_elsewhere = assigns(:touched_elsewhere).map(&:libelle)

      # what the repetition after it holds may read it in a condition
      it 'renders again the cards of what the repetitions after it hold' do
        subject

        expect(cards).to eq(['updated', 'after'])
        expect(cards_elsewhere).to eq(['a1', 'a2'])
        third_type_de_champ.children.each do |child|
          expect(response.body).to have_css("turbo-stream[action=replace][target='#{ActionView::RecordIdentifier.dom_id(child, :editor_error)}']")
        end
      end

      it 'leaves alone what a repetition holds when the repetition itself is updated' do
        post :update, params: default_params.merge(stable_id: third_type_de_champ.stable_id), format: :turbo_stream

        expect(cards).to eq(['updated'])
        expect(cards_elsewhere).to be_empty
      end
    end

    context 'when the champ was already removed (replayed autosave)' do
      let(:params) { default_params.merge(stable_id: @removed_stable_id) }

      before do
        @removed_stable_id = second_type_de_champ.stable_id
        procedure.draft_revision.remove_type_de_champ(@removed_stable_id)
      end

      it 'raises RecordNotFound (rendered as 404) instead of a 500 (RAILS-JZE)' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "validate" do
      let(:params) { default_params.deep_merge(type_de_champ: { libelle: '' }) }

      it do
        is_expected.to have_http_status(:ok)
        expect(assigns(:type_de_champs).map(&:stable_id)).to include(second_type_de_champ.stable_id)
        expect(flash.alert).to be_nil
      end
    end

    context 'keeping the type but submitting an option of another type' do
      # a stale tab can autosave the options of the previous type after a type change
      let(:params) { default_params.deep_merge(type_de_champ: { pre_rempli_hidden: '1' }) }

      it 'ignores the unknown option' do
        is_expected.to have_http_status(:ok)
        type_de_champ = second_type_de_champ
        expect(type_de_champ.libelle).to eq('updated')
        expect(type_de_champ.options['pre_rempli_hidden']).to be_nil
      end
    end

    context 'changing the type to header section' do
      let(:params) { default_params.deep_merge(type_de_champ: { type_champ: 'header_section' }) }

      render_views

      it 'makes an empty header section of it, its list item rendered again' do
        is_expected.to have_http_status(:ok)

        expect(procedure.draft_revision.reload.public_type_de_champs.map { [it.libelle, it.type_champ, it.children.size] })
          .to eq([['l1', 'integer_number', 0], ['updated', 'header_section', 0], ['l3', 'drop_down_list', 0]])
        expect(libelles(assigns(:changes).replaced)).to eq(['updated'])
        expect(response.body).to have_css("turbo-stream[action=replace][target='#{ActionView::RecordIdentifier.dom_id(second_type_de_champ, :type_de_champ_editor)}']")
      end

      it 'takes the following siblings when asked to' do
        subject
        patch :take_following_siblings, params: { procedure_id: procedure.id, stable_id: second_type_de_champ.stable_id }, format: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(second_type_de_champ.children.map(&:libelle)).to eq(['l3'])
        expect(removed).to eq(['l3'])
        expect(inserted).to eq(['l3'])
      end
    end

    context 'changing the type to formatted' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :textarea, libelle: 'l1' }]) }
      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: first_type_de_champ.stable_id,
          # the editor form submits the options of the previous type along the new type
          type_de_champ: { type_champ: 'formatted', character_limit: '' },
        }
      end

      it 'persists the formatted default options' do
        is_expected.to have_http_status(:ok)

        options = TypeDeChamp.where(id: first_type_de_champ.id).pick(:options)
        expect(options).to eq({
          'formatted_mode' => 'simple',
          'letters_accepted' => true,
          'numbers_accepted' => true,
          'special_characters_accepted' => true,
        })
      end
    end

    context 'changing the type to one without the previous type options' do
      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: third_type_de_champ.stable_id,
          # the editor form submits the options of the previous type along the new type
          type_de_champ: { type_champ: 'yes_no', drop_down_options_from_text: "a\nb" },
        }
      end

      it 'ignores the options unknown to the new type (RAILS-MF9)' do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to be_nil
        expect(TypeDeChamp.where(id: third_type_de_champ.id).pick(:type_champ)).to eq('yes_no')
      end
    end

    describe 'the « Nombre » menu entry' do
      def type_champ_of(type_de_champ) = TypeDeChamp.where(id: type_de_champ.id).pick(:type_champ)

      context 'choosing it on a text field' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'l1' }]) }
        let(:params) { { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, type_de_champ: { type_champ: 'numeric' } } }

        it 'makes it an integer, the toggle not being displayed yet' do
          is_expected.to have_http_status(:ok)
          expect(type_champ_of(first_type_de_champ)).to eq('integer_number')
        end
      end

      context 'turning the decimals toggle on' do
        let(:params) { default_params.deep_merge(type_de_champ: { type_champ: 'numeric', numeric_type_champ: 'decimal_number' }) }

        it 'makes the integer a decimal' do
          is_expected.to have_http_status(:ok)
          expect(type_champ_of(second_type_de_champ)).to eq('decimal_number')
        end
      end

      context 'turning the decimals toggle off' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :decimal_number, libelle: 'l1' }]) }
        let(:params) { { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, type_de_champ: { type_champ: 'numeric', numeric_type_champ: 'integer_number' } } }

        it 'makes the decimal an integer' do
          is_expected.to have_http_status(:ok)
          expect(type_champ_of(first_type_de_champ)).to eq('integer_number')
        end
      end

      context 'choosing another type while the toggle is still displayed' do
        let(:params) { default_params.deep_merge(type_de_champ: { type_champ: 'text', numeric_type_champ: 'integer_number' }) }

        it 'follows the menu and ignores the toggle' do
          is_expected.to have_http_status(:ok)
          expect(type_champ_of(second_type_de_champ)).to eq('text')
        end
      end

      context 'with an unexpected toggle value' do
        let(:params) { default_params.deep_merge(type_de_champ: { type_champ: 'numeric', numeric_type_champ: 'siret' }) }

        it 'falls back to an integer' do
          is_expected.to have_http_status(:ok)
          expect(type_champ_of(second_type_de_champ)).to eq('integer_number')
        end
      end

      context 'editing the libelle of a number used by routing' do
        let(:params) { default_params.deep_merge(type_de_champ: { type_champ: 'numeric', numeric_type_champ: 'integer_number' }) }

        before do
          allow_any_instance_of(TypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
        end

        it 'saves it, the type being unchanged' do
          is_expected.to have_http_status(:ok)
          expect(flash.alert).to be_nil
          expect(second_type_de_champ.libelle).to eq('updated')
        end
      end

      context 'editing the libelle of a decimal used by routing, its locked toggle sending nothing' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :decimal_number, libelle: 'l1' }]) }
        let(:params) { { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, type_de_champ: { type_champ: 'numeric', libelle: 'updated' } } }

        before do
          allow_any_instance_of(TypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
        end

        it 'keeps it a decimal and saves the libelle' do
          is_expected.to have_http_status(:ok)
          expect(flash.alert).to be_nil
          expect(type_champ_of(first_type_de_champ)).to eq('decimal_number')
          expect(TypeDeChamp.where(id: first_type_de_champ.id).pick(:libelle)).to eq('updated')
        end
      end
    end

    context 'rejected if type changed and routing involved' do
      let(:params) do
        default_params.deep_merge(type_de_champ: { type_champ: 'text', stable_id: third_type_de_champ.stable_id })
      end

      before do
        allow_any_instance_of(TypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.update.used_by_routing_rules", type_de_champ: 'l2'))
      end
    end

    context 'rejected if type changed and the repetition holds types de champ' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, libelle: 'held', children: [{ libelle: 'child' }] }, { type: :repetition, libelle: 'empty' }]) }
      let(:params) { { procedure_id: procedure.id, stable_id:, type_de_champ: { type_champ: 'text' } } }
      let(:stable_id) { first_type_de_champ.stable_id }

      it 'leaves it as it is, and shows why' do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.update.repetition_holding_champs", type_de_champ: 'held'))
        expect(procedure.draft_revision.reload.type_de_champs.map(&:libelle)).to eq(['held', 'child', 'empty'])
        expect(first_type_de_champ).to be_repetition
      end

      context 'when it holds nothing' do
        let(:stable_id) { second_type_de_champ.stable_id }

        it 'changes its type' do
          is_expected.to have_http_status(:ok)
          expect(flash.alert).to be_nil
          expect(second_type_de_champ.type_champ).to eq('text')
        end
      end
    end

    context 'rejected if type changed and referentiel url involved' do
      let(:params) do
        default_params.deep_merge(type_de_champ: { type_champ: 'text', stable_id: third_type_de_champ.stable_id })
      end

      before do
        allow_any_instance_of(TypeDeChamp).to receive(:used_by_referentiel_urls?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.update.used_by_referentiel_urls", type_de_champ: 'l2'))
      end
    end

    context 'changing the type of a reference dataset whose url mentions a field above' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'l1', stable_id: 100 }, { type: :referentiel, libelle: 'l2', stable_id: 200 }]) }
      let(:params) { { procedure_id: procedure.id, stable_id: 200, type_de_champ: { type_champ: 'text' } } }

      before do
        procedure.draft_revision.type_de_champs.find { it.stable_id == 200 }.update!(referentiel: create(:api_referentiel, :exact_match, mentioned_stable_id: 100))
      end

      it 'renders the mentioned field unlocked' do
        is_expected.to have_http_status(:ok)
        expect(cards).to include('l1')
        expect(procedure.draft_revision.reload.type_de_champ(100).type_champ_locked?).to be(false)
      end
    end

    context 'when the champ is used by the ineligibilite rules' do
      include Logic

      let(:ineligibilite_enabled) { true }
      let(:params) do
        default_params.deep_merge(type_de_champ: { type_champ: 'text' }, stable_id: first_type_de_champ.stable_id)
      end

      before do
        procedure.draft_revision.update!(
          ineligibilite_enabled:,
          ineligibilite_message: 'Vous n’êtes pas éligible',
          ineligibilite_rules: ds_eq(champ_value(first_type_de_champ.stable_id), constant(1))
        )
      end

      it 'rejects the type change' do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.update.used_by_ineligibilite_rules", type_de_champ: 'l1'))
        expect(first_type_de_champ.type_champ).to eq('integer_number')
      end

      context 'when the ineligibilite rules are disabled' do
        let(:ineligibilite_enabled) { false }

        it 'accepts the type change' do
          is_expected.to have_http_status(:ok)
          expect(flash.alert).to be_nil
          expect(first_type_de_champ.type_champ).to eq('text')
        end
      end
    end

    context 'with a dropdown list with a referentiel' do
      let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }
      let(:drop_down_list_type_de_champ) do
        procedure.draft_revision.public_root_type_de_champs.third
      end

      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: third_type_de_champ.stable_id,
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
          expect(Referentiel.last.type_de_champs).to eq [drop_down_list_type_de_champ]
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

      context 'when a binary file is uploaded with a spoofed text/csv content type' do
        let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/french-flag.gif', 'text/csv') }

        before { subject }

        it 'rejects the file based on sniffed content type, not declared content type' do
          expect(flash.alert).to eq("Importation impossible : veuillez importer un fichier CSV")
          expect(Referentiel.count).to eq(0)
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
               public_type_de_champs: [
                 { type: :multiple_drop_down_list, libelle: 'l1' },
               ])
      end
      let(:referentiel_file) { fixture_file_upload('spec/fixtures/files/modele-import-referentiel.csv', 'text/csv') }
      let(:multiple_drop_down_list_type_de_champ) do
        procedure.draft_revision.public_root_type_de_champs.first
      end
      let(:params) do
        {
          procedure_id: procedure.id,
          stable_id: multiple_drop_down_list_type_de_champ.stable_id,
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
          expect(Referentiel.last.type_de_champs).to eq [multiple_drop_down_list_type_de_champ]
          expect(Referentiel.last.name).to eq referentiel_file.original_filename
          expect(Referentiel.last.type).to eq 'Referentiels::CsvReferentiel'
          expect(ReferentielItem.first.data).to eq({ "row" => { "calorie_kcal" => "145", "dessert" => "Éclair au café", "poids_g" => "60" } })
          expect(ReferentielItem.first.referentiel_id).to eq(Referentiel.last.id)
        end
      end
    end
  end

  # l1, l2, l3 => l1, l3, l2
  # removed then inserted: l3, cards: l2 which sits further
  describe '#move_up' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: third_type_de_champ.stable_id }
    end

    subject { patch :move_up, params: params, format: :turbo_stream }

    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(second_type_de_champ.libelle).to eq('l3')
      expect(siblings).to eq(['l1', 'l3', 'l2'])
      expect(removed).to eq(['l3'])
      expect(inserted).to eq(['l3'])
      expect(cards).to eq(['l2'])
    end
  end

  # l1, l2, l3 => l2, l1, l3
  # removed then inserted: l1, cards: l2 which sits before
  describe '#move_down' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id }
    end

    subject { patch :move_down, params: params, format: :turbo_stream }

    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)

      expect(siblings).to eq(['l2', 'l1', 'l3'])
      expect(removed).to eq(['l1'])
      expect(inserted).to eq(['l1'])
      expect(cards).to eq(['l2'])
    end
  end

  describe 'moving in and out of a header section' do
    render_views

    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :header_section, libelle: 's', children: [{ libelle: 'l1' }] }, { libelle: 'l2' }]) }

    def section = first_type_de_champ

    it 'moves in the header section before it, then out' do
      patch :move_in, params: { procedure_id: procedure.id, stable_id: second_type_de_champ.stable_id }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(section.children.map(&:libelle)).to eq(['l1', 'l2'])
      expect([removed, inserted]).to all(eq(['l2']))
      expect(response.body).to have_css("turbo-stream[action=after][target='#{ActionView::RecordIdentifier.dom_id(section.children.first, :type_de_champ_editor)}']")

      patch :move_out, params: { procedure_id: procedure.id, stable_id: section.children.first.stable_id }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(procedure.draft_revision.reload.public_type_de_champs.map(&:libelle)).to eq(['s', 'l1'])
      expect(section.children.map(&:libelle)).to eq(['l2'])
    end

    it 'gives the focus back to the card of the one edited' do
      l2 = second_type_de_champ
      focused = -> (type_de_champ, control) { "turbo-stream[action=focus][target='#{ActionView::RecordIdentifier.dom_id(type_de_champ, control)}']" }

      # nothing left to take: the button is hidden
      patch :take_following_siblings, params: { procedure_id: procedure.id, stable_id: section.stable_id }, format: :turbo_stream
      expect(section.children.map(&:libelle)).to eq(['l1', 'l2'])
      expect(response.body).to have_css(focused.(section, :libelle))

      # out of any section: the opposite move
      patch :move_out, params: { procedure_id: procedure.id, stable_id: l2.stable_id }, format: :turbo_stream
      expect(response.body).to have_css(focused.(l2, :move_in_button))

      patch :move_in, params: { procedure_id: procedure.id, stable_id: l2.stable_id }, format: :turbo_stream
      expect(response.body).to have_css(focused.(l2, :move_out_button))

      # a move the card still offers
      patch :move_up, params: { procedure_id: procedure.id, stable_id: l2.stable_id }, format: :turbo_stream
      expect(section.children.map(&:libelle)).to eq(['l2', 'l1'])
      expect(response.body).to have_css(focused.(l2, :move_up_button))
    end

    it 'says why a move is refused, on the type de champ' do
      patch :move_out, params: { procedure_id: procedure.id, stable_id: second_type_de_champ.stable_id }, format: :turbo_stream

      expect(response).to have_http_status(:ok)
      # in the alert of the page, and on its card
      expect(response.body).to have_css("turbo-stream[action=replace][target='#{ActionView::RecordIdentifier.dom_id(second_type_de_champ, :editor_error)}']")
      expect(response.body).to include('types-de-champ-errors')
      expect(response.body.gsub('&nbsp;', "\u00a0").scan('« l2 » n’est dans aucune section.').size).to eq(2)
      expect(procedure.draft_revision.reload.public_type_de_champs.map(&:libelle)).to eq(['s', 'l2'])
    end
  end

  describe 'moving a champ already removed (replayed click)' do
    let(:removed_stable_id) { second_type_de_champ.stable_id }
    let(:params) { { procedure_id: procedure.id, stable_id: removed_stable_id } }

    before { procedure.draft_revision.remove_type_de_champ(removed_stable_id) }

    [:move_up, :move_down, :move_in, :move_out].each do |action|
      it "#{action} raises RecordNotFound (rendered as 404) instead of a 500 (RAILS-MPV, RAILS-MQH)" do
        expect { patch action, params:, format: :turbo_stream }.to raise_error(ActiveRecord::RecordNotFound)
        expect(procedure.draft_revision.reload.public_type_de_champs.map(&:libelle)).to eq(['l1', 'l3'])
      end
    end

    it 'move does as well, whichever of the two is gone' do
      [[removed_stable_id, first_type_de_champ.stable_id], [first_type_de_champ.stable_id, removed_stable_id]].each do |stable_id, target_stable_id|
        expect { patch :move, params: { procedure_id: procedure.id, stable_id:, place: "after:#{target_stable_id}" }, format: :turbo_stream }
          .to raise_error(ActiveRecord::RecordNotFound)
        expect(procedure.draft_revision.reload.public_type_de_champs.map(&:libelle)).to eq(['l1', 'l3'])
      end
    end
  end

  describe '#move' do
    # l1, l2, l3 => l2, l3, l1
    context 'after a type de champ further down' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, place: "after:#{third_type_de_champ.stable_id}" }
      end

      subject { patch :move, params: params, format: :turbo_stream }

      it do
        is_expected.to have_http_status(:ok)
        expect(siblings).to eq(['l2', 'l3', 'l1'])
        expect(removed).to eq(['l1'])
        expect(inserted).to eq(['l1'])
        expect(cards).to eq(['l2', 'l3'])
      end
    end

    # l1, l2, l3 => l3, l1, l2
    context 'first of the form' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_type_de_champ.stable_id, place: 'first' }
      end

      subject { patch :move, params: params, format: :turbo_stream }

      it do
        is_expected.to have_http_status(:ok)
        expect(siblings).to eq(['l3', 'l1', 'l2'])
        expect(removed).to eq(['l3'])
        expect(inserted).to eq(['l3'])
        expect(cards).to eq(['l1', 'l2'])
      end
    end

    context 'first of a header section, or of the repetition it sits in' do
      let(:procedure) do
        create(:procedure, public_type_de_champs: [
          { libelle: 'l1' },
          { type: :header_section, libelle: 's', children: [{ libelle: 'l2' }] },
          { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] },
        ])
      end

      it do
        section, repetition = second_type_de_champ, third_type_de_champ

        patch :move, params: { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, place: "first:#{section.stable_id}" }, format: :turbo_stream
        expect(first_type_de_champ.children.map(&:libelle)).to eq(['l1', 'l2'])

        patch :move, params: { procedure_id: procedure.id, stable_id: repetition.children.last.stable_id, place: 'first' }, format: :turbo_stream
        expect(second_type_de_champ.children.map(&:libelle)).to eq(['r2', 'r1'])
        expect(siblings).to eq(['r2', 'r1'])
      end
    end

    context 'on a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ libelle: 'l1' }, { libelle: 'l2' }, { libelle: 'l3' }]) }
      let(:params) do
        { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, place: "after:#{third_type_de_champ.stable_id}" }
      end

      it 'leaves the types de champ shared with the published revision as they are' do
        expect { patch :move, params:, format: :turbo_stream }
          .not_to change { TypeDeChamp.where(procedure:).count }

        expect(siblings).to eq(['l2', 'l3', 'l1'])
        expect(procedure.published_revision.public_root_type_de_champs.map(&:libelle)).to eq(['l1', 'l2', 'l3'])
      end
    end
  end

  # l1, l2, l3 => l1, l3
  # removed: l2, cards: l3 which sits before
  describe '#destroy' do
    let(:params) do
      { procedure_id: procedure.id, stable_id: second_type_de_champ.stable_id }
    end

    subject { delete :destroy, params: params, format: :turbo_stream }

    it do
      is_expected.to have_http_status(:ok)
      expect(flash.alert).to eq(nil)
      expect(siblings).to eq(['l1', 'l3'])
      expect(removed).to eq(['l2'])
      expect(inserted).to be_empty
      expect(cards).to eq(['l3'])
    end

    context 'when the champ was already removed (replayed double click)' do
      let(:params) { { procedure_id: procedure.id, stable_id: @removed_stable_id } }

      before do
        @removed_stable_id = second_type_de_champ.stable_id
        procedure.draft_revision.remove_type_de_champ(@removed_stable_id)
      end

      it 'raises RecordNotFound (rendered as 404) instead of a 500 (RAILS-JYT)' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'rejected if type changed and routing involved' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_type_de_champ.stable_id }
      end

      before do
        allow_any_instance_of(TypeDeChamp).to receive(:used_by_routing_rules?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.destroy.used_by_routing_rules", type_de_champ: 'l3'))
      end
    end

    context 'rejected if referentiel url involved' do
      let(:params) do
        { procedure_id: procedure.id, stable_id: third_type_de_champ.stable_id }
      end

      before do
        allow_any_instance_of(TypeDeChamp).to receive(:used_by_referentiel_urls?).and_return(true)
      end

      it do
        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.destroy.used_by_referentiel_urls", type_de_champ: 'l3'))
      end
    end

    context 'removing a reference dataset whose url mentions a field above' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'l1', stable_id: 100 }, { type: :referentiel, libelle: 'l2', stable_id: 200 }]) }
      let(:params) { { procedure_id: procedure.id, stable_id: 200 } }

      before do
        procedure.draft_revision.type_de_champs.find { it.stable_id == 200 }.update!(referentiel: create(:api_referentiel, :exact_match, mentioned_stable_id: 100))
      end

      it 'renders the mentioned field unlocked' do
        is_expected.to have_http_status(:ok)
        expect(cards).to include('l1')
        expect(procedure.draft_revision.reload.type_de_champ(100).type_champ_locked?).to be(false)
      end
    end

    context 'when the champ is used by the ineligibilite rules' do
      include Logic

      let(:params) do
        { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id }
      end

      before do
        procedure.draft_revision.update!(
          ineligibilite_enabled: true,
          ineligibilite_message: 'Vous n’êtes pas éligible',
          ineligibilite_rules: ds_eq(champ_value(first_type_de_champ.stable_id), constant(1))
        )
      end

      it 'rejects the deletion' do
        stable_id = first_type_de_champ.stable_id

        is_expected.to have_http_status(:ok)
        expect(flash.alert).to eq(I18n.t("activerecord.errors.type_de_champ.locked.destroy.used_by_ineligibilite_rules", type_de_champ: 'l1'))
        expect(procedure.draft_revision.reload.type_de_champs.map(&:stable_id)).to include(stable_id)
      end
    end
  end

  describe '#notice_explicative' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :explication }]) }
    let(:type_de_champ) { procedure.draft_revision.type_de_champs.first }
    let(:content) { 'notice' }
    let(:blob) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename: 'notice.txt', content_type: 'text/plain') }

    context 'when sending a valid blob' do
      it 'attaches the blob and responds with 200' do
        expect { put :notice_explicative, format: :turbo_stream, params: { stable_id: type_de_champ.stable_id, procedure_id: procedure.id, blob_signed_id: blob.signed_id } }
          .to change { type_de_champ.reload.notice_explicative.attached? }
          .from(false).to(true)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when sending an empty blob' do
      let(:content) { '' }

      it 'rejects it and responds with 422' do
        expect { put :notice_explicative, format: :turbo_stream, params: { stable_id: type_de_champ.stable_id, procedure_id: procedure.id, blob_signed_id: blob.signed_id } }
          .not_to change { type_de_champ.reload.notice_explicative.attached? }
        expect(response).to have_http_status(422)
        expect(response.parsed_body['errors'].join).to include('vide')
      end
    end
  end

  describe 'the files the editor shows' do
    render_views

    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :text, libelle: 'first' },
        { type: :piece_justificative },
        { type: :piece_justificative },
        { type: :explication },
        { type: :repetition, children: [{ type: :piece_justificative }, { type: :explication }] },
      ])
    end

    def count_type_de_champ_attachment_queries
      count = 0
      counter = -> (*, payload) { count += 1 if payload[:sql].include?('FROM "active_storage_attachments"') && payload[:type_casted_binds].include?('TypeDeChamp') }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { yield }
      count
    end

    it 'are loaded at once for the types de champ a stream renders' do
      params = { procedure_id: procedure.id, stable_id: first_type_de_champ.stable_id, type_de_champ: { libelle: 'updated' } }

      queries = count_type_de_champ_attachment_queries { post :update, params:, format: :turbo_stream }

      expect(response).to have_http_status(:ok)
      expect(assigns(:changes).cards.size).to eq(5)
      # the templates, the notices
      expect(queries).to eq(2)
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
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:public_type_de_champs) { [{ type: :text, libelle: 'Ancien', stable_id: 123 }] }
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
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) do
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

      libelles = procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)
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
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Champ A', stable_id: 100 }]) }
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
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'Champ A', stable_id: 100 }]) }
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
