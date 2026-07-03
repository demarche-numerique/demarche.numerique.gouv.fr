# frozen_string_literal: true

module Recovery
  class Importer
    attr_reader :dossiers

    def initialize(file_path: Recovery::Exporter::FILE_PATH)
      # rubocop:disable Security/MarshalLoad
      @dossiers = Marshal.load(File.read(file_path))
      # rubocop:enable Security/MarshalLoad
    end

    def load
      @dossiers.each do |dossier|
        if Dossier.exists?(dossier.id)
          puts "Dossier #{dossier.id} already exists"
          next
        end
        dossier.instance_variable_set :@new_record, true
        dossier_attributes = dossier.attributes.dup

        parent_dossier_id = dossier_attributes['parent_dossier_id']
        if parent_dossier_id && !Dossier.exists?(id: parent_dossier_id)
          dossier_attributes.delete('parent_dossier_id')
        end

        Dossier.insert(dossier_attributes)

        if dossier.etablissement.present?
          Etablissement.insert(dossier.etablissement.attributes)
          if dossier.etablissement.present?
            APIEntreprise::EtablissementJob.perform_later(dossier.etablissement.id, dossier.procedure.id)
          end

          dossier.etablissement.exercices.each do |exercice|
            Exercice.insert(exercice.attributes)
          end
        end
        if dossier.individual.present?
          Individual.insert(dossier.individual.attributes)
        end

        dossier.invites.each do |invite|
          Invite.insert(invite.attributes)
        end

        dossier.traitements.each do |traitement|
          Traitement.insert(traitement.attributes)
        end

        dossier.follows.each do |follow|
          if Instructeur.exists?(follow.instructeur_id)
            Follow.insert(follow.attributes)
          end
        end

        dossier.transfer_logs.each do |transfer|
          DossierTransferLog.insert(transfer.attributes)
        end

        dossier.commentaires.each do |commentaire|
          Commentaire.insert(commentaire.attributes)
          if commentaire.piece_jointe.attached?
            import(commentaire.piece_jointe)
          end
        end

        dossier.avis.each do |avis|
          Avis.insert(avis.attributes)

          if avis.introduction_file.attached?
            import(avis.introduction_file)
          end

          if avis.piece_justificative_file.attached?
            import(avis.piece_justificative_file)
          end
        end
        dossier.dossier_operation_logs.each do |dol|
          if dol.operation.nil?
            puts "dol nil: #{dol.id}"
            next
          end
          DossierOperationLog.insert(dol.attributes)

          if dol.serialized.attached?
            import(dol.serialized)
          end
        end

        if dossier.attestation.present?
          Attestation.insert(dossier.attestation.attributes)
          import(dossier.attestation.pdf)
        end

        if dossier.justificatif_motivation.attached?
          import(dossier.justificatif_motivation)
        end

        dossier.champ_data.each do |champ|
          champ.piece_justificative_file.each { |pj| import(pj) }

          if champ.etablissement.present?
            APIEntreprise::EtablissementJob.perform_later(champ.etablissement.id, dossier.procedure.id)

            champ.etablissement.exercices.each do |exercice|
              Exercice.insert(exercice.attributes)
            end

            Etablissement.insert(champ.etablissement.attributes)
          end

          ChampData.insert(champ.attributes)

          if champ.geo_areas.present?
            champ.geo_areas.each { GeoArea.insert(_1.attributes) }
          end
        end
        puts "imported dossier #{dossier.id}: #{Dossier.exists?(dossier.id)}"
      end
    end

    def import(pjs)
      attachments = pjs.respond_to?(:each) ? pjs : [pjs]
      attachments.each do |pj|
        ActiveStorage::Blob.insert(pj.blob.attributes)
        ActiveStorage::Attachment.insert(pj.attributes)
      end
    end
  end
end
