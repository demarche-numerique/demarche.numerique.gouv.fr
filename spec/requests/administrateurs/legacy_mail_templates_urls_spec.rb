# frozen_string_literal: true

describe 'legacy mail_templates URLs', type: :request do
  let(:procedure_id) { 42 }

  it 'redirects the index' do
    get "/admin/procedures/#{procedure_id}/mail_templates"
    expect(response).to redirect_to("/admin/procedures/#{procedure_id}/email_templates")
  end

  it 'redirects the editor to the renamed slug' do
    get "/admin/procedures/#{procedure_id}/mail_templates/closed_mail/edit"
    expect(response).to redirect_to("/admin/procedures/#{procedure_id}/email_templates/accepte/edit")
  end

  it 'redirects the preview iframe' do
    get "/admin/procedures/#{procedure_id}/mail_templates/refused_mail/preview"
    expect(response).to redirect_to("/admin/procedures/#{procedure_id}/email_templates/refuse/preview")
  end

  # The block form of redirect interpolates raw, so an id URI.parse chokes on
  # would raise instead of redirecting.
  it 'does not route ids it could not build a URL from' do
    get "/admin/procedures/#{procedure_id}/mail_templates/%0D%0A/edit"
    expect(response).to have_http_status(:not_found)

    get "/admin/procedures/x%20y/mail_templates/closed_mail/edit"
    expect(response).to have_http_status(:not_found)
  end

  # What is posted to a legacy path is served in place: a CSRF token is an HMAC
  # of the path the form was rendered for, so redirecting the save would get it
  # rejected.
  context 'what is posted to a legacy path' do
    let(:administrateur) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateur:) }
    let(:tiptap_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Salut" }] }] } }

    before { login_as administrateur.user, scope: :user }

    it 'saves without leaving the legacy path' do
      put "/admin/procedures/#{procedure.id}/mail_templates/without_continuation",
        params: { email_template: { tiptap_body: tiptap_body.to_json } }

      expect(response).to redirect_to(edit_admin_procedure_email_template_path(procedure, 'classe_sans_suite'))
      expect(procedure.reload.email_classe_sans_suite.json_body).to eq(tiptap_body)
    end

    it 'previews without leaving the legacy path' do
      post "/admin/procedures/#{procedure.id}/mail_templates/received_mail/preview",
        params: { email_template: { tiptap_body: tiptap_body.to_json } },
        headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Salut')
    end
  end
end
