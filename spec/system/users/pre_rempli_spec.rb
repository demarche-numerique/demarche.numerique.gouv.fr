# frozen_string_literal: true

describe 'Pre-rempli champ:', js: true do
  let(:password) { SECURE_PASSWORD }
  let(:instructeur) { create(:instructeur, password:) }
  let(:user) { create(:user, password:) }

  describe 'usager views a pre_rempli champ' do
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :pre_rempli, libelle: 'Référence interne' }]) }
    let(:dossier) { create(:dossier, :brouillon, :with_individual, user:, procedure:) }
    let(:tdc) { procedure.active_revision.root_public_types_de_champ.first }

    before do
      Flipper.enable(:pre_rempli_type_de_champ, procedure)
      dossier.project_champ(tdc).update!(value: 'REF-42')
      login_as user, scope: :user
    end

    context 'when visible (not hidden)' do
      it 'displays the value in a readonly input' do
        visit brouillon_dossier_path(dossier)

        expect(page).to have_text('Référence interne')
        expect(page).to have_field('Référence interne', with: 'REF-42', disabled: true)
      end
    end

    context 'when hidden (pre_rempli_hidden)' do
      before { tdc.record.update!(pre_rempli_hidden: "1") }

      it 'does not render the champ at all but preserves value after submission' do
        visit brouillon_dossier_path(dossier)

        expect(page).not_to have_text('Référence interne')

        click_on 'Déposer le dossier'
        click_on 'Accéder au dossier'

        dossier.reload
        expect(dossier.state).to eq('en_construction')
        expect(dossier.project_champ(tdc).value).to eq('REF-42')
      end
    end
  end

  describe 'pre_rempli champ via prefill URL' do
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :pre_rempli, libelle: 'Code projet' }]) }
    let(:tdc) { procedure.active_revision.root_public_types_de_champ.first }

    before do
      Flipper.enable(:pre_rempli_type_de_champ, procedure)
    end

    it 'assigns the value from prefill URL parameters' do
      visit "/users/sign_in"
      sign_in_with user.email, password

      visit commencer_path(
        path: procedure.path,
        "champ_#{tdc.to_typed_id_for_query}" => "PROJ-2026"
      )

      click_on "Poursuivre mon dossier prérempli"

      find('label', text: "Pour vous").click
      fill_in('Prénom', with: 'Jean', visible: true)
      fill_in('Nom', with: 'Dupont', visible: true)
      within "#identite-form" do
        click_on 'Continuer'
      end

      dossier = procedure.dossiers.last
      expect(page).to have_current_path(brouillon_dossier_path(dossier))
      expect(page).to have_field('Code projet', with: 'PROJ-2026', disabled: true)

      champ = dossier.project_champ(tdc)
      expect(champ.value).to eq('PROJ-2026')
      expect(champ.prefilled).to eq(true)
    end
  end

  describe 'instructeur views a pre_rempli champ' do
    let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur], types_de_champ_public: [{ type: :pre_rempli, libelle: 'Référence interne' }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
    let(:tdc) { procedure.active_revision.root_public_types_de_champ.first }

    before do
      Flipper.enable(:pre_rempli_type_de_champ, procedure)
      dossier.project_champ(tdc).update!(value: 'REF-INSTR-99')
      login_as instructeur.user, scope: :user
    end

    it 'displays the pre_rempli value on the dossier page' do
      visit instructeur_dossier_path(procedure, dossier)

      expect(page).to have_text('Référence interne')
      expect(page).to have_text('REF-INSTR-99')
    end
  end

  describe 'expert views a pre_rempli champ' do
    let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur], types_de_champ_public: [{ type: :pre_rempli, libelle: 'Code expert' }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
    let(:tdc) { procedure.active_revision.root_public_types_de_champ.first }
    let(:expert) { create(:expert) }
    let(:experts_procedure) { create(:experts_procedure, expert:, procedure:) }
    let!(:avis) { create(:avis, dossier:, claimant: instructeur, experts_procedure:) }

    before do
      Flipper.enable(:pre_rempli_type_de_champ, procedure)
      dossier.project_champ(tdc).update!(value: 'EXP-VALUE')
      login_as expert.user, scope: :user
    end

    it 'displays the pre_rempli value for the expert' do
      visit expert_avis_path(avis.dossier.procedure, avis)

      expect(page).to have_text('Code expert')
      expect(page).to have_text('EXP-VALUE')
    end
  end
end
