# frozen_string_literal: true

describe 'As an administrateur i can edit a mail template with the tiptap editor', js: true do
  let(:administrateur) { administrateurs.default }
  let(:procedure) { procedures.individual }

  before { login_as administrateur.user, scope: :user }

  scenario 'Mail template tiptap editor' do
    visit edit_admin_procedure_email_template_path(procedure, 'passe_en_instruction')

    expect(page).to have_css('.tiptap-editor')
    expect(page).to have_button('Italique')
    expect(page).to have_button('Saut de ligne')

    # The default template body (Trix HTML + `--tags--`, including a `<br>`) must be
    # converted and loaded into the editor, not silently dropped as invalid content.
    within('#email_template_tiptap_body_editor') do
      expect(page).to have_content('Bonjour')
      expect(page).to have_css('.fr-tag', text: 'numéro du dossier')
    end

    within('#mail-body-preview') { expect(page).to have_css('iframe') }

    body_group = find('.fr-input-group', text: 'Corps de l’email')
    within(body_group) do
      find('button[data-tag-id="dossier_number"]').click
    end

    within('#email_template_tiptap_body_editor') do
      expect(page).to have_css('.fr-tag', text: 'numéro du dossier')
    end

    # The subject offers the same tags, hidden behind a show/hide toggle.
    click_on 'Balises disponibles'
    within('#email_template_tiptap_subject_tags') do
      find('button[data-tag-id="dossier_number"]').click
    end
    within('#email_template_tiptap_subject_editor') do
      expect(page).to have_css('.fr-tag', text: 'numéro du dossier')
    end

    click_on 'Enregistrer'
    expect(page).to have_content('Email mis à jour')

    mail = procedure.reload.email_passe_en_instruction
    expect(mail.json_body).to be_present
    expect(TiptapService.used_tags_and_libelle_for(mail.json_body.deep_symbolize_keys).map(&:first)).to include('dossier_number')
    expect(TiptapService.used_tags_and_libelle_for(mail.json_subject.deep_symbolize_keys).map(&:first)).to include('dossier_number')
  end
end
