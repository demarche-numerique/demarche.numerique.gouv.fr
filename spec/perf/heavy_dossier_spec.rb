# frozen_string_literal: true

describe Users::DossiersController, type: :controller do
  let(:user) { create(:user) }
  before { sign_in(user) }

  context 'with a demarche with 100 conditional champs' do
    include Logic

    let(:nb_champ) { 100 }
    let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
    let(:types_de_champ_public) { (0...nb_champ).map { |i| { type: :yes_no, libelle: "c_#{i}" } } }
    let(:dossier) { create(:dossier, user:, procedure:) }

    let(:last_champ) { dossier.root_champs_public.last }

    before do
      tdcs = procedure.active_revision.types_de_champ.to_a

      # one champ is visible if the previous champ is true
      (nb_champ - 1).times do |i|
        condition = ds_eq(champ_value(tdcs[i].stable_id), constant(true))
        tdcs[i + 1].record.update!(condition:)
      end

      # all champs are visible
      dossier.root_champs_public.take((nb_champ - 1)).each { |champ| champ.update_columns(value: 'true') }
      last_champ.update_columns(value: 'false')
    end

    describe 'ensure setup' do
      it '', :slow do
        preloaded_dossier = DossierPreloader.load_one(dossier)
        expect(preloaded_dossier.valid?).to eq(true)

        expect(preloaded_dossier.root_champs_public.last.visible?).to eq(true)
        expect(last_champ.reload.true?).to eq(false)
      end
    end

    describe 'PATCH #update (la mise a jour d un champ)' do
      let(:payload) do
        {
          id: dossier.id,
          validate: true,
          dossier: {
            groupe_instructeur_id: dossier.groupe_instructeur_id,
            champs_public_attributes: {
              last_champ.public_id => {
                with_public_id: true,
                value: true,
              },
            },
          },
        }
      end

      it do
        query_count = 0

        ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") do
          patch :update, params: payload, format: :turbo_stream
        end

        expect(last_champ.reload.true?).to eq(true)
        expect(query_count).to be <= 50
      end
    end

    describe 'POST #submit_en_construction' do
      before do
        dossier.passer_en_construction!
      end

      it '', :slow do
        query_count = 0

        ActiveSupport::Notifications.subscribed(lambda { |*_args| query_count += 1 }, "sql.active_record") do
          post :submit_en_construction, params: { id: dossier.id }
        end

        expect(query_count).to be <= 70
      end
    end
  end
end
