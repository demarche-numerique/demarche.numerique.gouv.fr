# frozen_string_literal: true

describe 'instructeurs/dossiers/show', type: :view do
  let(:current_instructeur) { create(:instructeur) }
  let(:dossier) { create(:dossier, :en_construction) }
  let(:statut) { { statut: 'tous' } }
  let(:procedure_presentation) { double(instructeur: current_instructeur, procedure: dossier.procedure, displayed_columns: []) }
  let(:notifications) { [] }
  let(:notifications_sticker) { { demande: false, annotations_instructeur: false, avis_externe: false, messagerie: false } }

  before do
    sign_in(current_instructeur.user)
    allow(view).to receive(:current_instructeur).and_return(current_instructeur)
    allow(controller).to receive(:params).and_return(statut:)
    assign(:dossier, dossier)
    assign(:procedure_presentation, procedure_presentation)
    assign(:notifications, notifications)
    assign(:notifications_sticker, notifications_sticker)
  end

  subject { render }

  it 'renders the header' do
    expect(subject).to have_text("Dossier n° #{dossier.id}")
  end

  context 'when procedure statut / page was saved in session' do
    it 'renders back button with saved state' do
      expect(subject).to have_selector("a[href=\"#{instructeur_procedure_path(dossier.procedure, statut: statut)}\"]")
    end
  end

  it 'renders the dossier infos' do
    expect(subject).to have_text('Identité')
    expect(subject).to have_text('Demande')
  end

  it 'renders the correct dossier state' do
    expect(subject).to have_text('en construction')
  end

  context 'en_construction' do
    let!(:instructeur) { create(:instructeur) }
    let(:dossier) { create(:dossier, :en_construction) }

    it 'displays the correct actions' do
      within("form[action=\"#{passer_en_instruction_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Passer en instruction', disabled: false)
      end
      within("form[action=\"#{follow_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Suivre')
      end
      expect(subject).to have_button('Demander une correction')
      expect(subject).to have_selector('.header-actions ul:first-child > li.instruction-button', count: 1)
    end

    context 'with pending correction' do
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: 'attente_correction') }

      before do
        create(:dossier_correction, dossier:)
        assign(:notifications, [notification])
      end

      it { expect(subject).to have_button('Passer en instruction', disabled: false) }

      it 'shows the correction badge' do
        expect(subject).to have_selector('.fr-badge', text: "En attente de correction")
      end

      context 'with procedure blocking pending correction' do
        before { Flipper.enable(:blocking_pending_correction, dossier.procedure) }

        it 'disable the instruction button' do
          expect(subject).to have_button('Passer en instruction', disabled: true)
          expect(subject).to have_content('Le passage en instruction est impossible')
        end
      end
    end

    context 'with resolved correction' do
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: 'dossier_modifie') }

      before { assign(:notifications, [notification]) }

      it 'shows the resolved badge' do
        expect(subject).to have_selector('.fr-badge--new', text: "Dossier modifié")
      end
    end
  end

  context 'en_instruction' do
    let(:dossier) { create(:dossier, :en_instruction) }

    before do
      current_instructeur.followed_dossiers << dossier
      render
    end

    it 'displays the correct actions' do
      within("form[action=\"#{unfollow_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Ne plus suivre')
      end

      expect(subject).to have_button('Repasser en construction')
      expect(subject).to have_selector('.en-construction-menu .fr-btn', count: 5)

      expect(subject).to have_button('Instruire le dossier')
      expect(subject).to have_selector('.instruction-button .fr-btn', count: 13)
    end
  end

  context 'accepte' do
    let(:dossier) { create(:dossier, :accepte) }

    it 'displays the correct actions' do
      within("form[action=\"#{repasser_en_instruction_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Repasser en instruction')
      end
      within("form[action=\"#{archive_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Replacer dans“traités“')
      end
      expect(subject).to have_selector('[title^="Mettre à la corbeille"]')
      expect(subject).to have_selector('.header-actions ul:first-child .fr-btn', count: 3)
    end
  end

  context 'supprime' do
    let(:dossier) { create(:dossier, :accepte) }

    before do
      dossier.hide_and_keep_track!(current_instructeur, :instructeur_request)
      render
    end

    it 'displays the correct actions' do
      within("form[action=\"#{restore_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Restaurer')
      end
      expect(subject).to have_selector('.header-actions ul:first-child .fr-btn', count: 1)
    end
  end

  context 'expirant' do
    let(:procedure) { create(:procedure, :published, duree_conservation_dossiers_dans_ds: 6, procedure_expires_when_termine_enabled: true) }
    let!(:dossier) { create(:dossier, state: :accepte, procedure: procedure, processed_at: 175.days.ago) }

    before { dossier.update_expired_at }

    it 'displays the correct actions' do
      expect(subject).to have_text('Conserver un mois de plus')
      within("form[action=\"#{repasser_en_instruction_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Repasser en instruction')
      end
      expect(subject).to have_selector('.header-actions ul:first-child .fr-btn', count: 2)
    end
  end

  context 'archived' do
    let(:dossier) { create(:dossier, :accepte, :archived) }

    it 'displays the correct actions' do
      within("form[action=\"#{unarchive_instructeur_dossier_path(dossier.procedure, dossier)}\"]") do
        expect(subject).to have_button('Désarchiver le dossier')
      end
      expect(subject).to have_selector('[title^="Mettre à la corbeille"]')
      expect(subject).to have_selector('.header-actions ul:first-child .fr-btn', count: 2)
    end
  end

  context 'when the dossier was submitted with FranceConnect' do
    let(:france_connect_information) { build(:france_connect_information) }
    let(:user) { build(:user, france_connect_informations: [france_connect_information]) }
    let(:procedure1) { create(:procedure, :with_type_de_champ, for_individual: true) }
    let(:dossier) { create(:dossier, procedure: procedure1, user: user, submitted_with_france_connect: true) }

    before do
      render
    end

    it 'fills the individual with the informations from France Connect' do
      expect(rendered).to have_text("Le dossier a été déposé par le compte de #{france_connect_information.given_name} #{france_connect_information.family_name}, authentifié par FranceConnect")
    end
  end

  describe 'entreprise degraded mode' do
    context 'etablissement complete' do
      let(:dossier) { create(:dossier, :en_construction, :with_entreprise, as_degraded_mode: false) }

      it 'contains no warning' do
        expect(subject).not_to have_text("Les services de l’INSEE sont indisponibles")
      end
    end

    context 'etablissement in degraded mode' do
      let(:dossier) { create(:dossier, :en_construction, :with_entreprise, as_degraded_mode: true) }

      it 'warns the instructeur' do
        expect(subject).to have_text("Les services de l’INSEE sont indisponibles")
      end
    end
  end

  describe 'accuse de lecture ' do
    context 'dossier not termine' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: create(:procedure, :accuse_lecture)) }

      it 'does not display a text about accuse de lecture for instructeur' do
        expect(subject).not_to have_text('Cette démarche est soumise à un accusé de lecture')
      end
    end

    context 'dossier termine with accuse de lecture not accepted by user' do
      let(:dossier) { create(:dossier, :accepte, procedure: create(:procedure, :accuse_lecture)) }

      it 'displays a text about accuse de lecture for instructeur' do
        expect(subject).to have_text('Cette démarche est soumise à un accusé de lecture')
        expect(subject).to have_text('L’usager n’a pas encore pris connaissance de la décision concernant son dossier')
      end
    end

    context 'dossier termine with accuse de lecture accepted by user' do
      let(:dossier) { create(:dossier, :accepte, accuse_lecture_agreement_at: Time.zone.now, procedure: create(:procedure, :accuse_lecture)) }

      it 'displays a text about accuse de lecture for instructeur' do
        expect(subject).to have_text('Cette démarche est soumise à un accusé de lecture')
        expect(subject).to have_text('L’usager a pris connaissance de la décision concernant son dossier le')
      end
    end
  end

  describe 'when header_sections are present' do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) do
      [
        { type: :header_section, level: 1, libelle: 'l1' },
      ]
    end
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    it 'displays a link to header_section' do
      expect(subject).to have_selector('a.fr-sidemenu__link', text: 'l1')
    end
  end

  describe "Dossier labels" do
    let(:procedure) { create(:procedure, :with_labels) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }

    context "Procedure without labels" do
      let(:procedure_without_labels) { create(:procedure) }
      let(:dossier) { create(:dossier, :en_construction, procedure: procedure_without_labels) }
      it 'does not display button to add label or dropdown' do
        expect(subject).not_to have_text("Ajouter un label")
        expect(subject).not_to have_text("À examiner")
      end
    end

    context "Dossier without labels" do
      it 'displays button with text to add label' do
        expect(subject).to have_text("Ajouter un label")
        expect(subject).to have_selector("button.dropdown-button")
        expect(subject).to have_text("À examiner", count: 1)
        within('.dropdown') do
          expect(subject).to have_text("À examiner", count: 1)
        end
      end
    end

    context "Dossier with labels" do
      before do
        DossierLabel.create(dossier_id: dossier.id, label_id: dossier.procedure.labels.first.id)
      end

      it 'displays labels and button without text to add label' do
        expect(subject).not_to have_text("Ajouter un label")
        expect(subject).to have_selector("button.dropdown-button")
        expect(subject).to have_text("À examiner", count: 2)
        within('.dropdown') do
          expect(subject).to have_text("À examiner", count: 1)
        end
      end
    end
  end
end
