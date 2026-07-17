# frozen_string_literal: true

describe 'Dossier::Recovery::LifeCycle' do
  describe '.load_export_destroy_and_import' do
    let(:procedure) do
      create(:procedure,
             types_de_champ_public: [
               { type: :repetition, children: [{ type: :piece_justificative }], mandatory: false },
               { type: :carte },
               { type: :siret },
             ])
    end

    let(:some_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/white.png', 'image/png') }
    let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon) }
    let(:fp) { Rails.root.join('spec', 'fixtures', 'export.dump') }
    let(:dossier) do
      d = create(:dossier, :with_populated_champs, procedure:)

      repetition(d).add_row(updated_by: 'test')
      pj_champ(d).piece_justificative_file.attach(some_file)
      carte(d).update(geo_areas: [geo_area])
      d.etablissement = create(:etablissement, :with_exercices)
      d.etablissement.entreprise_attestation_sociale.attach(some_file)
      d.etablissement.entreprise_attestation_fiscale.attach(some_file)

      siret(d).update(etablissement: create(:etablissement, :with_exercices))
      siret(d).etablissement.entreprise_attestation_sociale.attach(some_file)
      siret(d).etablissement.entreprise_attestation_fiscale.attach(some_file)

      d.individual = build(:individual)

      d.attestation = build(:attestation, :with_pdf)
      d.justificatif_motivation.attach(some_file)

      d.commentaires << build(:commentaire, :with_file)

      d.invites << build(:invite, :with_user)

      d.avis << build(:avis, :with_introduction, :with_piece_justificative)

      d.traitements.accepter(motivation: 'oui', processed_at: Time.zone.now)
      d.save

      d.dossier_operation_logs << build(:dossier_operation_log, :with_serialized)

      d.transfer_logs.create(from: create(:user), to: create(:user))

      d
    end

    def repetition(d) = d.root_champs_public.find(&:repetition?)
    def pj_champ(d) = d.champ_data.find_by(type: "Champs::PieceJustificativeChamp")
    def carte(d) = d.champ_data.find_by(type: "Champs::CarteChamp")
    def siret(d) = d.champ_data.find_by(type: "Champs::SiretChamp")

    def cleanup_export_file
      if File.exist?(fp)
        FileUtils.rm(fp)
      end
    end
    let(:instructeur) { create(:instructeur) }

    before do
      instructeur.followed_dossiers << dossier
      cleanup_export_file
    end

    after { cleanup_export_file }
    it 'reloads the full grappe', :slow do
      expect(dossier.champ_data.count).not_to be(0)

      @dossier_ids = [dossier.id]

      Recovery::Exporter.new(dossier_ids: @dossier_ids, file_path: fp).dump
      Dossier.where(id: @dossier_ids).destroy_all
      Recovery::Importer.new(file_path: fp).load

      expect(Dossier.exists?(dossier.id)).to be(true)

      reloaded_dossier = Dossier.find(dossier.id)

      expect(reloaded_dossier.champ_data.count).not_to be(0)

      expect(repetition(reloaded_dossier).rows.flat_map(&:champs).map(&:type)).to match_array(["Champs::PieceJustificativeChamp", "Champs::PieceJustificativeChamp", "Champs::PieceJustificativeChamp"])
      expect(pj_champ(reloaded_dossier).piece_justificative_file).to be_attached
      expect(carte(reloaded_dossier).geo_areas).to be_present

      expect(reloaded_dossier.etablissement.exercices).to be_present

      # launch a job
      # expect(reloaded_dossier.etablissement.entreprise_attestation_sociale).to be_attached
      # expect(reloaded_dossier.etablissement.entreprise_attestation_fiscale).to be_attached

      expect(siret(reloaded_dossier).etablissement.exercices).to be_present

      # launch a job
      # expect(siret(reloaded_dossier).etablissement.entreprise_attestation_sociale).to be_attached
      # expect(siret(reloaded_dossier).etablissement.entreprise_attestation_fiscale).to be_attached

      expect(reloaded_dossier.individual).to be_present
      expect(reloaded_dossier.attestation.pdf).to be_attached
      expect(reloaded_dossier.justificatif_motivation).to be_attached

      expect(reloaded_dossier.commentaires.first.piece_jointe).to be_attached

      expect(reloaded_dossier.invites.first.user).to be_present
      expect(reloaded_dossier.followers_instructeurs).to match_array([instructeur])

      expect(reloaded_dossier.avis.first.introduction_file).to be_attached
      expect(reloaded_dossier.avis.first.piece_justificative_file).to be_attached

      expect(reloaded_dossier.traitements).to be_present

      expect(reloaded_dossier.dossier_operation_logs.first.serialized).to be_attached

      expect(reloaded_dossier.transfer_logs).to be_present
    end

    it 'skip parent_dossier_id when dossier does not exists any more', :slow do
      parent = create(:dossier)
      dossier.update!(parent_dossier_id: parent.id)
      @dossier_ids = [dossier.id]

      Recovery::Exporter.new(dossier_ids: @dossier_ids, file_path: fp).dump
      Dossier.where(id: @dossier_ids).destroy_all
      parent.destroy
      Recovery::Importer.new(file_path: fp).load

      expect(Dossier.exists?(dossier.id)).to be(true)
      expect(Dossier.exists?(parent.id)).to be(false)
    end

    it 'does not insert follow when instructeur does not exists any more', :slow do
      @dossier_ids = [dossier.id]

      Recovery::Exporter.new(dossier_ids: @dossier_ids, file_path: fp).dump
      Dossier.where(id: @dossier_ids).destroy_all
      instructeur.destroy
      Recovery::Importer.new(file_path: fp).load

      expect(Dossier.exists?(dossier.id)).to be(true)

      reloaded_dossier = Dossier.find(dossier.id)

      expect(reloaded_dossier.followers_instructeurs).to match_array([])
    end
  end
end
