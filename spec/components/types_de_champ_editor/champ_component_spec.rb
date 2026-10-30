# frozen_string_literal: true

describe TypesDeChampEditor::ChampComponent, type: :component do
  describe 'render' do
    let(:component) { described_class.new(coordinate:) }
    let(:routing_rules_stable_ids) { [] }
    let(:ineligibilite_rules_used?) { false }

    before do
      allow_any_instance_of(Procedure).to receive(:stable_ids_used_by_routing_rules).and_return(routing_rules_stable_ids)
      allow_any_instance_of(ProcedureRevisionTypeDeChamp).to receive(:used_by_ineligibilite_rules?).and_return(ineligibilite_rules_used?)
      render_inline(component)
    end

    describe 'tdc dropdown' do
      let(:procedure) { create(:procedure, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }] }
      let(:tdc) { procedure.draft_revision.type_de_champs.first }
      let(:coordinate) { procedure.draft_revision.coordinate_for(tdc) }

      context 'drop down tdc not used for routing' do
        it do
          expect(page).not_to have_text(/utilisé pour\nle routage/)
        end
      end

      context 'drop down tdc used for routing' do
        let(:routing_rules_stable_ids) { [tdc.stable_id] }

        it do
          expect(page).to have_text(/utilisé pour\nle routage/)
        end
      end

      context 'drop down tdc used for ineligibilite_rules' do
        let(:ineligibilite_rules_used?) { true }

        it do
          expect(page).to have_text(/l’éligibilité des dossiers/)
        end
      end

      context 'tdc used for prefill' do
        let(:public_type_de_champs) do
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

    describe 'tdc explication' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :explication }]) }
      let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }
      it 'includes an uploader for notice_explicative' do
        expect(page).to have_css('label', text: 'Notice explicative')
        expect(page).to have_css('input[type=file]')
      end
    end

    describe 'tdc number' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: type_champ }]) }
      let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }
      let(:decimals_toggle) { 'Ce nombre peut comprendre des chiffres après la virgule (décimal)' }
      let(:locked_hint) { 'Ce champ est utilisé pour le routage ou l’éligibilité des dossiers : vous ne pouvez pas changer ce réglage.' }
      let(:toggle_id) { ActionView::RecordIdentifier.dom_id(coordinate.type_de_champ, :numeric_type_champ) }
      let(:hint_id) { ActionView::RecordIdentifier.dom_id(coordinate.type_de_champ, :numeric_type_champ_hint) }

      context 'when it is an integer' do
        let(:type_champ) { :integer_number }

        it 'offers the toggle without any hint' do
          expect(page).to have_unchecked_field(decimals_toggle)
          expect(page).not_to have_text(locked_hint)
          expect(page).not_to have_text('FranceConnect')
          expect(page).not_to have_css("##{toggle_id}[aria-describedby]")
        end
      end

      context 'when it is a decimal' do
        let(:type_champ) { :decimal_number }

        it 'offers the toggle without any hint' do
          expect(page).to have_checked_field(decimals_toggle)
          expect(page).not_to have_text(locked_hint)
          expect(page).not_to have_text('FranceConnect')
        end
      end

      context 'when it is not a number' do
        let(:type_champ) { :text }

        it { expect(page).not_to have_field(decimals_toggle) }
      end

      context 'when it is used by routing' do
        let(:type_champ) { :decimal_number }
        let(:routing_rules_stable_ids) { [coordinate.stable_id] }

        it 'locks the toggle and says why' do
          expect(page).to have_checked_field(decimals_toggle, disabled: true)
          expect(page).to have_css("##{toggle_id}[aria-describedby='#{hint_id}']")
          expect(page).to have_css("##{hint_id}", text: locked_hint)
        end
      end

      context 'when it is used by eligibility rules' do
        let(:type_champ) { :integer_number }
        let(:ineligibilite_rules_used?) { true }

        it 'locks the toggle and says why' do
          expect(page).to have_unchecked_field(decimals_toggle, disabled: true)
          expect(page).to have_text(locked_hint)
        end
      end
    end

    describe 'tdc quotient familial' do
      let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs: [{ type: :text }]) }

      context "when coordinate public" do
        let(:public_type_de_champs) { [{ type: :quotient_familial, libelle: 'Quotient familial' }] }
        let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }

        it 'does not have mandatory configuration' do
          expect(page).not_to have_field('Champ obligatoire')
        end
      end
    end

    describe 'select champ position' do
      let(:tdc) { procedure.draft_revision.type_de_champs.first }
      let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'a' }]) }
      it 'does not have select to move champs' do
        expect(page).to have_css("select##{ActionView::RecordIdentifier.dom_id(coordinate, :move_and_morph)}")
      end
    end
  end

  describe 'piece_justificative field' do
    let(:procedure) { create(:procedure, piece_justificative_multiple: true, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:coordinate) { procedure.draft_revision.public_revision_type_de_champs.first }
    let(:component) { described_class.new(coordinate:) }

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

    context 'when pj_limit_formats is enabled' do
      let(:tdc) { procedure.draft_revision.type_de_champs.first }

      before do
        tdc.update!(pj_limit_formats: true, pj_format_families: ['document_texte'])
        render_inline(component)
      end

      it 'displays tooltip with trailing ellipsis' do
        expect(page).to have_css('.fr-tooltip', text: /Exemples :.*\.\.\./)
      end
    end

    context 'when nature is titre_identite' do
      let(:tdc) { procedure.draft_revision.type_de_champs.first }

      before do
        tdc.update!(nature: 'titre_identite')
        render_inline(component)
      end

      it 'does not display multi-file mention' do
        expect(page).not_to have_text("joindre plusieurs fichiers")
      end

      it 'displays accepted formats with plain extensions in bold' do
        expect(page).to have_css('strong', text: '.jpg, .jpeg, .png')
        expect(page).to have_css('strong', text: 'taille maximale de 20 Mo')
        expect(page).not_to have_text('image / scan')
      end
    end

    context 'when nature is rib' do
      let(:tdc) { procedure.draft_revision.type_de_champs.first }

      before do
        tdc.update!(nature: 'rib')
        render_inline(component)
      end

      it 'does not display multi-file mention' do
        expect(page).not_to have_text("joindre plusieurs fichiers")
      end

      it 'displays accepted formats with plain extensions in bold' do
        expect(page).to have_css('strong', text: '.pdf, .doc, .docx, .jpg, .jpeg, .png')
        expect(page).not_to have_text('document texte')
      end
    end
  end
end
