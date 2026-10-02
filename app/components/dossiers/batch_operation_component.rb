# frozen_string_literal: true

class Dossiers::BatchOperationComponent < ApplicationComponent
  attr_reader :statut, :procedure

  # followed_dossier_ids est résolu en une requête pour toute la page : appelé par
  # ligne, `instructeur.follow?(dossier)` faisait un EXISTS par dossier affiché.
  def initialize(statut:, procedure:, followed_dossier_ids: [])
    @statut = statut
    @procedure = procedure
    @followed_dossier_ids = followed_dossier_ids
  end

  def operations_for_dossier(dossier)
    allowed_operations =
      case dossier.state
      when Dossier.states.fetch(:en_construction)
        [
          BatchOperation.operations.fetch(:passer_en_instruction), BatchOperation.operations.fetch(:repousser_expiration), BatchOperation.operations.fetch(:create_avis),
          BatchOperation.operations.fetch(:restaurer_repousser_expiration),
        ]
      when Dossier.states.fetch(:en_instruction)
        [
          BatchOperation.operations.fetch(:repasser_en_construction), BatchOperation.operations.fetch(:create_avis), 'instruction',
        ]
      when Dossier.states.fetch(:accepte), Dossier.states.fetch(:refuse), Dossier.states.fetch(:sans_suite)
        [
          BatchOperation.operations.fetch(:archiver), BatchOperation.operations.fetch(:desarchiver), BatchOperation.operations.fetch(:supprimer),
          BatchOperation.operations.fetch(:repousser_expiration), restore_operation_for(dossier),
        ]
      else
        []
      end.append(BatchOperation.operations.fetch(:create_commentaire))

    allowed_operations + follow_operations_for(dossier)
  end

  def follow_operations_for(dossier)
    if @followed_dossier_ids.include?(dossier.id)
      [BatchOperation.operations.fetch(:unfollow)]
    else
      [BatchOperation.operations.fetch(:follow)]
    end
  end

  private

  def available_operations
    case @statut
    when 'a-suivre' then
      {
        options:
          [
            {
              label: t(".operations.passer_en_instruction"),
              operation: BatchOperation.operations.fetch(:passer_en_instruction),
            },
            {
              label: t(".operations.follow"),
              operation: BatchOperation.operations.fetch(:follow),
            },
            {
              label: t(".operations.create_commentaire"),
              operation: BatchOperation.operations.fetch(:create_commentaire),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'commentaire' },
              aria:  'modal-commentaire-batch',
            },
          ],
      }
    when 'archives' then
      {
        options:
          [
            {
              label: t(".operations.desarchiver"),
              operation: BatchOperation.operations.fetch(:desarchiver),
            },
          ],
      }
    when 'traites' then
      {
        options:
          [
            archiver_option,
            {
              label: t(".operations.supprimer"),
              operation: BatchOperation.operations.fetch(:supprimer),
            },
            {
              label: t(".operations.create_commentaire"),
              operation: BatchOperation.operations.fetch(:create_commentaire),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'commentaire' },
              aria:  'modal-commentaire-batch',
            },
          ],
      }
    when 'expirant' then
      {
        options:
          [
            {
              label: t(".operations.repousser_expiration"),
              operation: BatchOperation.operations.fetch(:repousser_expiration),
            },
          ],
      }
    when 'supprimes' then
      {
        options:
          [
            {
              label: t(".operations.restaurer"),
              operation: BatchOperation.operations.fetch(:restaurer),
            },
            {
              label: t(".operations.restaurer_repousser_expiration"),
              operation: BatchOperation.operations.fetch(:restaurer_repousser_expiration),
            },
          ],
      }
    when 'suivis' then
      {
        options:
          [

            {
              label: t(".operations.passer_en_instruction"),
              operation: BatchOperation.operations.fetch(:passer_en_instruction),
            },

            {
              instruction: true,
            },

            {
              label: t(".operations.unfollow"),
              operation: BatchOperation.operations.fetch(:unfollow),
            },

            {
              label: t(".operations.repasser_en_construction"),
              operation: BatchOperation.operations.fetch(:repasser_en_construction),
            },

            {
              label: t(".operations.create_avis"),
              operation: BatchOperation.operations.fetch(:create_avis),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'avis' },
              aria:  'modal-avis-batch',

            },

            {
              label: t(".operations.create_commentaire"),
              operation: BatchOperation.operations.fetch(:create_commentaire),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'commentaire' },
              aria:  'modal-commentaire-batch',

            },
          ],
      }
    when 'tous' then
      {
        options:
          [
            {
              label: t(".operations.create_commentaire"),
              operation: BatchOperation.operations.fetch(:create_commentaire),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'commentaire' },
              aria:  'modal-commentaire-batch',

            },

            {
              instruction: true,
            },

            {
              label: t(".operations.follow"),
              operation: BatchOperation.operations.fetch(:follow),
            },

            {
              label: t(".operations.unfollow"),
              operation: BatchOperation.operations.fetch(:unfollow),
            },

            {
              label: t(".operations.passer_en_instruction"),
              operation: BatchOperation.operations.fetch(:passer_en_instruction),
            },

            {
              label: t(".operations.repasser_en_construction"),
              operation: BatchOperation.operations.fetch(:repasser_en_construction),
            },

            archiver_option,
            {
              label: t(".operations.supprimer"),
              operation: BatchOperation.operations.fetch(:supprimer),
            },

            {
              label: t(".operations.create_avis"),
              operation: BatchOperation.operations.fetch(:create_avis),
              modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'avis' },
              aria:  'modal-avis-batch',

            },

          ],
      }
    else
      {
        options: [],
      }
    end
  end

  def archiver_option
    option = { label: t(".operations.archiver"), operation: BatchOperation.operations.fetch(:archiver) }

    if current_instructeur.archive_warning_dismissed?
      option
    else
      option.merge(
        modal_data: { action: 'batch-operation#injectSelectedIdsIntoModal', 'fr-opened': "false", 'modal-type': 'archive' },
        aria: 'modal-archive-batch'
      )
    end
  end

  def icons
    {
      accepter: 'fr-icon-success-line',
      archiver: 'fr-icon-folder-2-line',
      desarchiver: 'fr-icon-upload-2-line',
      follow: 'fr-icon-star-line',
      passer_en_instruction: 'fr-icon-edit-line',
      repasser_en_construction: 'fr-icon-draft-line',
      supprimer: 'fr-icon-delete-line',
      restaurer: 'fr-icon-refresh-line',
      unfollow: 'fr-icon-star-fill',
      create_avis: 'fr-icon-questionnaire-line',
      create_commentaire: 'fr-icon-mail-line',
      restaurer_repousser_expiration: 'fr-icon-arrow-right-up-line',
    }
  end

  def expert_review_disallowed?(operation)
    operation == 'create_avis' && procedure.disallow_expert_review?
  end

  def restore_operation_for(dossier)
    if dossier.hidden_by_expired?
      BatchOperation.operations.fetch(:restaurer_repousser_expiration)
    else
      BatchOperation.operations.fetch(:restaurer)
    end
  end
end
