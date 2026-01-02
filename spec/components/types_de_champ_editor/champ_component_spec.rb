# frozen_string_literal: true

describe TypesDeChampEditor::ChampComponent, type: :component do
  describe 'render' do
    let(:component) { described_class.new(coordinate:, upper_coordinates: []) }
    let(:routing_rules_stable_ids) { [] }
    let(:ineligibilite_rules_used?) { false }

    before do
      Flipper.enable_actor(:engagement_juridique_type_de_champ, procedure)
      allow_any_instance_of(Procedure).to receive(:stable_ids_used_by_routing_rules).and_return(routing_rules_stable_ids)
      allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_ineligibilite_rules?).and_return(ineligibilite_rules_used?)
      render_inline(component)
    end

    describe 'tdc dropdown' do
      let(:procedure) { create(:procedure, types_de_champ_public:) }
      let(:types_de_champ_public) { [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }] }
      let(:tdc) { procedure.draft_revision.types_de_champ.first }
      let(:coordinate) { procedure.draft_revision.coordinate_for(tdc) }

      context 'drop down tdc not used for routing' do
        it do
          expect(page).not_to have_text(/utilisé pour\nle routage/)
          expect(page).not_to have_css("select[disabled=\"disabled\"]")
        end
      end

      context 'drop down tdc used for routing' do
        let(:routing_rules_stable_ids) { [tdc.stable_id] }

        it do
          expect(page).to have_css("select[disabled=\"disabled\"]")
          expect(page).to have_text(/utilisé pour\nle routage/)
        end
      end

      context 'drop down tdc used for ineligibilite_rules' do
        let(:ineligibilite_rules_used?) { true }

        it do
          expect(page).to have_css("select[disabled=\"disabled\"]")
          expect(page).to have_text(/l’eligibilité des dossiers/)
        end
      end

      context 'tdc used for prefill' do
        let(:types_de_champ_public) do
          [
            {
              type: :referentiel,
              stable_id: 1,
              referentiel: create(:api_referentiel, :exact_match, :with_exact_match_response),
              referentiel_mapping: {
                '$.jsonpath' => {
                  'prefill' => '1',
                  'type' => 'drop_down_list',
                  'prefill_stable_id' => 2,
                },
              },
            },
            { type: :drop_down_list, stable_id: 2, libelle: 'Votre ville', options: ['Paris', 'Lyon'] },
          ]
        end
        let(:coordinate) { procedure.draft_revision.coordinate_and_tdc(2).first }
        it do
          expect(page).to have_text(/Champ prérempli/)
        end
      end
    end

    describe 'tdc ej' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }], types_de_champ_private: [{ type: :text }]) }

      context 'when coordinate public' do
        let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }

        it 'does not include Engagement Juridique' do
          expect(page).not_to have_css('option', text: "Engagement Juridique")
        end
      end

      context 'when coordinate private' do
        let(:coordinate) { procedure.draft_revision.revision_types_de_champ_private.first }

        it 'includes Engagement Juridique' do
          expect(page).to have_css('option', text: "Engagement Juridique")
        end
      end
    end

    describe 'tdc explication' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :explication }]) }
      let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }
      it 'includes an uploader for notice_explicative' do
        expect(page).to have_css('label', text: 'Notice explicative')
        expect(page).to have_css('input[type=file]')
      end
    end

    describe 'tdc quotient familial' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :quotient_familial, libelle: 'Quotient familial (FranceConnect)' }]) }
      let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }

      it 'does not have mandatory configuration' do
        expect(page).to have_css('input[type="text"][value="Quotient familial"]')
        expect(page).not_to have_field('Champ obligatoire')
      end
    end

    describe 'select champ position' do
      let(:tdc) { procedure.draft_revision.types_de_champ.first }
      let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text, libelle: 'a' }]) }
      it 'does not have select to move champs' do
        expect(page).to have_css("select##{ActionView::RecordIdentifier.dom_id(coordinate, :move_and_morph)}")
      end
    end
  end

  describe 'ACCEPTED_TYPES' do
    it 'contains expected conversions' do
      expect(described_class::ACCEPTED_TYPES).to include(
        "checkbox" => ["yes_no", "text", "textarea", "formatted"],
        "civilite" => ["text", "textarea", "formatted"],
        "date" => ["datetime", "text", "textarea", "formatted"],
        "datetime" => ["date", "text", "textarea", "formatted"],
        "decimal_number" => ["integer_number", "text", "textarea", "formatted"],
        "drop_down_list" => ["multiple_drop_down_list", "text", "textarea", "formatted"],
        "email" => ["text", "textarea", "formatted"],
        "formatted" => ["textarea", "text", "email", "phone"],
        "integer_number" => ["decimal_number", "text", "textarea", "formatted"],
        "multiple_drop_down_list" => ["drop_down_list", "text", "textarea", "formatted"],
        "phone" => ["text", "textarea", "formatted"],
        "text" => ["textarea", "formatted", "email", "phone", "decimal_number", "integer_number"],
        "textarea" => ["text", "formatted"],
        "yes_no" => ["checkbox", "text", "textarea", "formatted"]
      )
    end
  end

  describe 'piece_justificative field' do
    let(:procedure) { create(:procedure, piece_justificative_multiple: true, types_de_champ_public: [{ type: :piece_justificative }]) }
    let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }
    let(:component) { described_class.new(coordinate:, upper_coordinates: []) }

    before do
      allow_any_instance_of(Procedure).to receive(:stable_ids_used_by_routing_rules).and_return([])
      allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_ineligibilite_rules?).and_return(false)
      render_inline(component)
    end

    it 'displays max file size hint' do
      expect(page).to have_text("Taille maximale autorisée : 200 Mo")
    end

    it 'displays "joindre" in multi-file mention' do
      expect(page).to have_text("Les usagers pourront joindre plusieurs fichiers si nécessaire.")
      expect(page).not_to have_text("envoyer plusieurs fichiers")
    end

    context 'when nature is titre_identite' do
      let(:tdc) { procedure.draft_revision.types_de_champ.first }

      before do
        tdc.update!(nature: 'TITRE_IDENTITE')
        render_inline(component)
      end

      it 'does not display multi-file mention' do
        expect(page).not_to have_text("joindre plusieurs fichiers")
      end
    end

    context 'when nature is RIB' do
      let(:tdc) { procedure.draft_revision.types_de_champ.first }

      before do
        tdc.update!(nature: 'RIB')
        render_inline(component)
      end

      it 'does not display multi-file mention' do
        expect(page).not_to have_text("joindre plusieurs fichiers")
      end
    end
  end

  describe 'hide old titre_identite in creation list' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }]) }
    let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }
    let(:component) { described_class.new(coordinate:, upper_coordinates: []) }

    it 'does not list Titre identité' do
      render_inline(component)
      expect(page).not_to have_css('option', text: 'Titre identité')
    end
  end
end
