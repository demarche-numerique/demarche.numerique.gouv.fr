# frozen_string_literal: true

describe Instructeurs::DossiersController, type: :controller do
  let(:instructeur) { create(:instructeur) }
  let(:user) { instructeur.user }
  before { sign_in(user) }

  context 'with a demarche with 100 conditional champs', caching: true do
    include Logic

    let(:nb_champ) { 100 }
    let(:procedure) { create(:procedure, :published, types_de_champ_public:, instructeurs: [instructeur]) }
    let(:types_de_champ_public) do
      (0...nb_champ).map { |i| { type: :yes_no, libelle: "c_#{i}" } } +
        (0...nb_champ).map { |i| { type: :piece_justificative, libelle: "pj_#{i}" } }
    end
    let(:dossier) { create(:dossier, :en_construction, user:, procedure:) }

    let(:last_yes_no_champ) { dossier.root_champs_public[99] }

    before do
      tdcs = procedure.active_revision.types_de_champ.to_a

      # one champ is visible if the previous champ is true
      (nb_champ - 1).times do |i|
        condition = ds_eq(champ_value(tdcs[i].stable_id), constant(true))
        tdcs[i + 1].record.update!(condition:)
      end

      # all champs are visible
      dossier.root_champs_public.take((nb_champ - 1)).each { |champ| champ.update_columns(value: 'true') }
      last_yes_no_champ.update_columns(value: 'false')

      # attachements to the piece justificative champs
      dossier.root_champs_public.filter(&:piece_justificative?).each do |champ|
        champ.piece_justificative_file.attach(
          io: Rails.root.join('spec/fixtures/files/logo_test_procedure.png').open,
          filename: 'logo_test_procedure.png',
          content_type: 'image/png',
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end
    end

    describe 'show' do
      render_views

      it '', :slow do
        query_count = 0

        ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") do
          get :show, params: { procedure_id: procedure.id, dossier_id: dossier.id, statut: 'a-suivre' }
        end

        expect(query_count).to be <= 124
      end
    end
  end
end
