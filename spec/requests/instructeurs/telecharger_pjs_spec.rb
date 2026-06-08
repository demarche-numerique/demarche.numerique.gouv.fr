# frozen_string_literal: true

# Request spec (full Rack stack) because #telecharger_pjs streams the zip via
# zip_kit. Controller specs no longer materialize a streamed Rack body under
# Rails 8, so the streamed bytes must be asserted at the request level.
describe "Instructeurs::DossiersController#telecharger_pjs", type: :request do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }
  let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }

  before { login_as(instructeur.user, scope: :user) }

  subject do
    get telecharger_pjs_instructeur_dossier_path(procedure_id: procedure.id, dossier_id: dossier.id)
    response
  end

  it 'includes an attachment' do
    expect(subject.headers['Content-Disposition']).to start_with('attachment; ')
  end

  it 'streams an extractable zip' do
    Tempfile.create(['test', '.zip']) do |f|
      f.binmode
      f.write(subject.body)
      f.close

      file_names = Zip::File.open(f.path) { |zip| zip.entries.map(&:name) }

      expect(file_names.size).to eq(1)
      expect(file_names.first).to start_with("dossier-#{dossier.id}/export-")
    end
  end
end
