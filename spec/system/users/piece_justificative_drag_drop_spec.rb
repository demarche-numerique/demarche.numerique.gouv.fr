# frozen_string_literal: true

describe 'Piece justificative drag and drop', js: true do
  let(:password) { SECURE_PASSWORD }
  let!(:user) { create(:user, password: password) }

  context 'drag and drop UI and accessibility' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Document' }] }
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
    let(:dossier) { user.dossiers.last }

    before do
      login_as(user, scope: :user)
      visit commencer_path(path: procedure.path)
      click_on 'Commencer la démarche'
      fill_individual
      expect(page).to have_current_path(brouillon_dossier_path(dossier))
      visit brouillon_dossier_path(dossier)
    end

    scenario 'clicking the button opens file picker only once' do
      within '.editable-champ-piece_justificative' do
        # Spy on input.click() calls
        page.execute_script(<<~JS)
          const input = document.querySelector('.attachment-input');
          input._clickCount = 0;
          const originalClick = input.click.bind(input);
          input.click = function() { input._clickCount++; originalClick(); };
        JS

        find('.fr-btn--secondary', text: 'Choisir des fichiers').click

        click_count = page.evaluate_script("document.querySelector('.attachment-input')._clickCount")
        expect(click_count).to eq(1)
      end
    end

    scenario 'displays complete drag and drop interface with ARIA attributes' do
      within '.editable-champ-piece_justificative' do
        # Structure de base
        expect(page).to have_css('.attachment-drop-zone')
        drop_area = find('.attachment-drop-area')

        # Textes et boutons (PJ uses MultipleComponent with default max=10, so plural)
        expect(page).to have_text('Faites glisser et déposez vos fichiers ici')
        expect(page).to have_css('.fr-btn--secondary', text: 'Choisir des fichiers')

        # Accessibilité ARIA
        expect(drop_area['role']).to eq('button')
        expect(drop_area['tabindex']).to eq('0')
        expect(drop_area['aria-label']).to include('Zone de glisser-déposer')
        expect(page).to have_selector('[data-attachment-error][aria-live="assertive"]')
      end
    end
  end

  context 'file size and format constraints display' do
    scenario 'shows 200 Mo limit for regular PJ' do
      procedure_pj = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, libelle: 'Document' }])
      login_as(user, scope: :user)
      visit commencer_path(path: procedure_pj.path)
      click_on 'Commencer la démarche'
      fill_individual

      within find('.editable-champ', text: 'Document') do
        expect(page).to have_text('Taille maximale par fichier : 200 Mo')
      end
    end

    scenario 'shows 20 Mo limit and formats for titre identite' do
      procedure_ti = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, libelle: 'Pièce d\'identité', nature: 'titre_identite' }])
      login_as(user, scope: :user)
      visit commencer_path(path: procedure_ti.path)
      click_on 'Commencer la démarche'
      fill_individual

      within find('.editable-champ', text: 'Pièce d\'identité') do
        expect(page).to have_text('Taille maximale par fichier : 20 Mo')
        expect(page).to have_text(/Pièce attendue :.*Carte nationale.*passeport.*titre de séjour/i)
        expect(page).to have_text(/jpeg|png/i)
      end
    end

    scenario 'shows formats for RIB' do
      procedure_rib = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, libelle: 'RIB', nature: 'rib' }])
      login_as(user, scope: :user)
      visit commencer_path(path: procedure_rib.path)
      click_on 'Commencer la démarche'
      fill_individual

      within find('.editable-champ', text: 'RIB') do
        expect(page).to have_text('Formats acceptés : .pdf, .doc, .docx, .jpg, .jpeg, .png')
      end
    end
  end

  context 'client-side validation and error handling' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'Documents' }] }
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
    let(:dossier) { user.dossiers.last }

    before do
      allow_any_instance_of(EditableChamp::PieceJustificativeComponent).to receive(:max).and_return(2)
      login_as(user, scope: :user)
      visit commencer_path(path: procedure.path)
      click_on 'Commencer la démarche'
      fill_individual
      expect(page).to have_current_path(brouillon_dossier_path(dossier))
      visit brouillon_dossier_path(dossier)
    end

    scenario 'validates file count and shows DSFR error when limit exceeded' do
      within find('.editable-champ', text: 'Documents') do
        # Upload 3 fichiers d'un coup alors que le max est 2
        attach_file('Documents', [
          Rails.root.join('spec/fixtures/files/file.pdf'),
          Rails.root.join('spec/fixtures/files/image-no-exif.jpg'),
          Rails.root.join('spec/fixtures/files/image-no-rotation.jpg'),
        ])

        # Vérifier que les 2 premiers sont acceptés
        expect(page).to have_text('file.pdf', wait: 5)
        expect(page).to have_text('image-no-exif.jpg', wait: 5)

        # Vérifier l'affichage du message d'erreur DSFR
        within('[data-attachment-error]') do
          expect(page).to have_selector('.fr-message--error', text: /Le nombre de fichiers maximum/i)
        end

        # Vérifier que le 3ème fichier n'a pas été ajouté
        expect(page).not_to have_text('image-no-rotation.jpg')

        # Supprimer un fichier pour libérer de la place
        click_on 'Supprimer le fichier file.pdf'

        # Attendre que la suppression soit effective
        expect(page).not_to have_text('file.pdf', wait: 5)

        # Ajouter un nouveau fichier
        attach_file('Documents', Rails.root.join('spec/fixtures/files/image-no-rotation.jpg'))

        # Le message doit avoir disparu
        expect(page).to have_selector('[data-attachment-error].hidden', visible: :all)
      end
    end

    scenario 'validates file size using titre_identite nature (20 Mo limit)' do
      # Créer un fichier légèrement au-dessus de 20 Mo
      large_content = 'x' * (21 * 1024 * 1024) # 21 Mo
      large_file_path = Rails.root.join('tmp', 'large_test_file.jpg')
      File.write(large_file_path, large_content)

      # Créer une procédure avec titre_identite (limite 20 Mo)
      procedure_ti = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, libelle: 'Pièce d\'identité', nature: 'titre_identite' }])
      visit commencer_path(path: procedure_ti.path)
      click_on 'Commencer la démarche'
      fill_individual
      expect(page).to have_current_path(brouillon_dossier_path(user.dossiers.last))

      begin
        within find('.editable-champ', text: 'Pièce d\'identité') do
          # Tenter l'upload du gros fichier
          attach_file('Pièce d\'identité', large_file_path)

          # Vérifier le message d'erreur de taille
          within('[data-attachment-error]') do
            expect(page).to have_selector('.fr-message--error', text: /La taille maximale du fichier autorisée est/i)
            expect(page).to have_text(/20.*Mo/i)
          end

          # Vérifier que le fichier n'a pas été uploadé
          expect(page).not_to have_selector('.direct-upload')
        end
      ensure
        File.delete(large_file_path) if File.exist?(large_file_path)
      end
    end

    scenario 'validates file format and shows accepted extensions' do
      # Créer un fichier avec une extension non acceptée (.txt)
      invalid_file_path = Rails.root.join('tmp', 'invalid_document.txt')
      File.write(invalid_file_path, 'test content')

      # Créer une procédure avec titre_identite (accepte seulement JPEG/PNG)
      procedure_ti = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, libelle: 'Pièce d\'identité', nature: 'titre_identite' }])
      visit commencer_path(path: procedure_ti.path)
      click_on 'Commencer la démarche'
      fill_individual
      expect(page).to have_current_path(brouillon_dossier_path(user.dossiers.last))

      begin
        within find('.editable-champ', text: 'Pièce d\'identité') do
          # Tenter l'upload d'un fichier .txt (non accepté pour titre_identite)
          attach_file('Pièce d\'identité', invalid_file_path, visible: false)

          # Vérifier le message d'erreur de format
          within('[data-attachment-error]') do
            expect(page).to have_selector('.fr-message--error', text: /Les\s+formats\s+de\s+fichier\s+acceptés\s+sont\s+:\s+.jpg,\s+.jpeg,\s+.png/i)
          end

          # Vérifier que le fichier n'a pas été uploadé
          expect(page).not_to have_selector('.direct-upload')
        end

        # Test avec un fichier valide
        within find('.editable-champ', text: 'Pièce d\'identité') do
          # Upload un fichier PNG (accepté pour titre_identite)
          attach_file('Pièce d\'identité', Rails.root.join('spec/fixtures/files/white.png'))

          # Vérifier que le fichier est en cours d'upload (pas d'erreur)
          expect(page).to have_selector('.direct-upload', wait: 2)
          expect(page).to have_selector('[data-attachment-error].hidden', count: 1, visible: false)
        end
      ensure
        File.delete(invalid_file_path) if File.exist?(invalid_file_path)
      end
    end
  end

  context 'multiple files management' do
    let(:types_de_champ_public) { [{ type: :piece_justificative, libelle: 'All types' }, { type: :piece_justificative, libelle: 'Données géo', pj_limit_formats: '1', pj_format_families: ['donnees'] }] }
    let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public:) }
    let(:dossier) { user.dossiers.last }

    before do
      login_as(user, scope: :user)
      visit commencer_path(path: procedure.path)
      click_on 'Commencer la démarche'
      fill_individual
      expect(page).to have_current_path(brouillon_dossier_path(dossier))
      visit brouillon_dossier_path(dossier)
    end

    scenario 'manages multiple uploads, deletions and preserves dropzone visibility' do
      within find('.editable-champ', text: 'All types') do
        # Drop zone visible initially
        expect(page).to have_css('.attachment-drop-zone')

        # Upload first file
        attach_file('All types', Rails.root.join('spec/fixtures/files/file.pdf'))
        expect(page).to have_text('file.pdf', wait: 5)

        # Drop zone should STILL be visible (max not reached)
        expect(page).to have_css('.attachment-drop-zone')
        expect(page).to have_css('.fr-btn--secondary', text: 'Choisir des fichiers')

        # Upload second file
        attach_file('All types', Rails.root.join('spec/fixtures/files/white.png'))
        expect(page).to have_text('white.png', wait: 5)

        # Delete the first file
        click_on 'Supprimer le fichier file.pdf'

        # Drop zone should still be visible after deletion
        expect(page).to have_css('.attachment-drop-zone')
        expect(page).to have_css('.fr-btn--secondary', text: 'Choisir des fichiers')

        # Upload third file
        attach_file('All types', Rails.root.join('spec/fixtures/files/black.png'))
        expect(page).to have_text('black.png', wait: 5)

        # File list should contain white.png and black.png
        expect(page).to have_css('.attachment-files-list')
        expect(page).to have_text('white.png')
        expect(page).to have_text('black.png')
        expect(page).not_to have_text('file.pdf')
      end

      # Upload Outlook .msg on a regular PJ champ (browsers don't reliably map .msg to its MIME type)
      within find('.editable-champ', text: 'All types') do
        attach_file('All types', Rails.root.join('spec/fixtures/files/sample.msg'))
        expect(page).to have_no_selector('.fr-message--error', wait: 3)
        expect(page).to have_text('sample.msg', wait: 5)
      end

      # Upload KML on the donnees-restricted champ (browsers don't reliably map .kml to its MIME type)
      within find('.editable-champ', text: 'Données géo') do
        attach_file('Données géo', Rails.root.join('spec/fixtures/files/sample.kml'))
        expect(page).to have_no_selector('.fr-message--error', wait: 3)
        expect(page).to have_text('sample.kml', wait: 5)
      end
    end
  end

  context 'advanced features' do
    scenario 'retries failed upload and recovers gracefully' do
      procedure_pjs = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, mandatory: true, libelle: 'Pièce justificative 1' }])
      login_as(user, scope: :user)
      visit commencer_path(path: procedure_pjs.path)
      click_on 'Commencer la démarche'
      fill_individual

      # Make the subsequent auto-upload request fail
      allow_any_instance_of(Champs::PieceJustificativeController).to receive(:update) do |instance|
        instance.render json: { errors: ["Une erreur est survenue"] }, status: :bad_request
      end

      attach_file('Pièce justificative 1', Rails.root.join('spec/fixtures/files/file.pdf'))
      expect(page).to have_css('p', text: "Une erreur est survenue", visible: :visible, wait: 5)
      expect(page).to have_button('Réessayer', visible: true)
      expect(page).to have_button('Déposer le dossier', disabled: false)

      allow_any_instance_of(Champs::PieceJustificativeController).to receive(:update).and_call_original

      # Test that retrying after a failure works
      click_on('Réessayer', visible: true, wait: 5)
      expect(page).to have_text('file.pdf')
      expect(page).to have_button('Déposer le dossier', disabled: false)
      expect(page).to have_button("Supprimer", title: "Supprimer le fichier file.pdf")

      # Reload and verify persistence
      visit current_path
      expect(page).to have_text('file.pdf')
    end

    scenario 'uploads multiple files on same champ with antivirus processing' do
      procedure_pjs = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, mandatory: true, libelle: 'Pièce justificative 1' }])
      login_as(user, scope: :user)
      visit commencer_path(path: procedure_pjs.path)
      click_on 'Commencer la démarche'
      fill_individual

      attach_file('Pièce justificative 1', Rails.root.join('spec/fixtures/files/file.pdf'))
      expect(page).to have_text('file.pdf')

      attach_file('Pièce justificative 1', Rails.root.join('spec/fixtures/files/white.png'))
      expect(page).to have_text('white.png')

      click_on("Supprimer le fichier file.pdf")
      file_input = find_field('Pièce justificative 1', visible: :all)
      live_region_selector = "##{file_input[:id]}-aria-live"
      expect(page).to have_css(live_region_selector, text: "La pièce jointe (file.pdf) a bien été supprimée.", visible: :all)

      attach_file('Pièce justificative 1', Rails.root.join('spec/fixtures/files/black.png'))

      # Mark all attachments as safe to test turbo poll
      # They are not immediately attached in db, so we have to wait a bit before continuing
      # NOTE: we're using files not used in other tests to avoid conflicts with concurrent tests
      attachments = Timeout.timeout(5) do
        filenames = ['white.png', 'black.png']
        attachments = ActiveStorage::Attachment.where(name: "piece_justificative_file").includes(:blob).filter do |attachment|
          filenames.include?(attachment.filename.to_s)
        end

        fail ActiveRecord::RecordNotFound, "Not all attachments where found yet" unless attachments.count == filenames.count

        attachments
      rescue ActiveRecord::RecordNotFound
        sleep 0.2
        retry
      end

      attachments.each do |attachment|
        attachment.blob.virus_scan_result = ActiveStorage::VirusScanner::SAFE
        attachment.save!
      end

      visit current_path

      expect(page).not_to have_text('file.pdf')
      expect(page).to have_text('white.png')
      expect(page).to have_text('black.png')
    end

    scenario 'handles old procedures with disabled PJ validation' do
      old_procedure_with_disabled_pj_validation = create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :piece_justificative, mandatory: true, libelle: 'Pièce justificative 1', skip_pj_validation: true }])
      login_as(user, scope: :user)
      visit commencer_path(path: old_procedure_with_disabled_pj_validation.path)
      click_on 'Commencer la démarche'
      fill_individual

      # Test invalid file type
      attach_file('Pièce justificative 1', Rails.root.join('spec/fixtures/files/invalid_file_format.json'))
      expect(page).to have_no_text("La pièce justificative n'est pas d'un type accepté")
    end
  end

  def fill_individual
    find('label', text: "Pour vous").click
    fill_in('Prénom', with: 'prenom', visible: true)
    fill_in('Nom', with: 'Nom', visible: true)
    within "#identite-form" do
      click_on 'Continuer'
    end
    expect(page).to have_current_path(brouillon_dossier_path(user.dossiers.last))
  end
end
