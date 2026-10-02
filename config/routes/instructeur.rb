# frozen_string_literal: true

scope module: 'instructeurs', as: 'instructeur', defaults: { nav_bar_profile: :instructeur } do
  resource :rdv_connections, only: [:show, :destroy]
  resources :procedures, only: [] do
    resources :export_templates, only: [:new, :create, :edit, :update, :destroy] do
      collection do
        put 'preview'
      end
    end

    collection do
      get :order_positions
      patch :update_order_positions
      get :select_procedure
      get :synthese
      get :counters
    end

    get 'display_notifications', defaults: { format: :turbo_stream }
  end

  resources :procedure_presentation, only: [:update] do
    member do
      get 'customize_filters'
      post 'update_filter'
      post 'refresh_filters'
      post 'persist_filters'
      post 'toggle_filters_expanded'
      post 'clear_all_filters'
      post 'reset_to_admin_default'
    end
  end

  resources :procedures, only: [:index], param: :procedure_id do
    member do
      #
      # nested navigation, all those route are hit during an instructeur instruction navigation context
      #   must keep track of last view statut page
      #
      constraints statut: /a-suivre|suivis|traites|tous|supprimes|expirant|archives/ do
        get :show, path: "(:statut)", defaults: { statut: 'a-suivre' } # optional because some url may still live on with /procedure/:id

        resources :dossiers, only: [:show, :destroy], param: :dossier_id, path: "(:statut)/dossiers", defaults: { statut: 'a-suivre' } do
          member do
            resources :commentaires, only: [:destroy] do
              member do
                post :cancel_correction
              end
            end
            resources :rdvs, only: [:create]
            get 'original' => 'dossiers#show_submitted_revision', as: :original
            get 'modifier' => 'edit#show', as: :edit
            patch 'modifier' => 'edit#submit', as: :submit
            patch 'modifier/valider' => 'edit#validate', as: :validate_edit
            patch 'update' => 'edit#update', as: :update
            get 'champs/:stable_id' => 'edit#champ', as: :champ
            get 'next'
            get 'previous'
            post 'repousser-expiration' => 'dossiers#extend_conservation'
            post 'repousser-expiration-and-restore' => 'dossiers#extend_conservation_and_restore'
            post 'dossier_labels' => 'dossiers#dossier_labels'
            get 'messagerie'
            get 'annotations-privees' => 'dossiers#annotations_privees'
            get 'avis'
            get 'avis_new'
            get 'personnes-impliquees' => 'dossiers#personnes_impliquees'
            get 'rendez-vous' => 'dossiers#rendez_vous'
            get 'rendez-vous/connexion' => 'dossiers#rdv_connection'
            patch 'follow'
            patch 'unfollow'
            patch 'archive'
            patch 'unarchive'
            patch 'restore'
            post 'commentaire' => 'dossiers#create_commentaire'
            post 'passer-en-instruction' => 'dossiers#passer_en_instruction'
            post 'repasser-en-construction' => 'dossiers#repasser_en_construction'
            post 'repasser-en-instruction' => 'dossiers#repasser_en_instruction'
            post 'terminer'
            post 'pending_correction'
            post 'send-to-instructeurs' => 'dossiers#send_to_instructeurs'
            post 'avis' => 'dossiers#create_avis'
            get 'reaffectation'
            get 'pieces_jointes'
            post 'reaffecter'
            post 'instruction_modal/:operation', to: 'dossiers#instruction_modal', as: :instruction_modal
          end
        end

        resources :avis, only: [], path: "(:statut)/dossiers", defaults: { statut: 'a-suivre' } do
          member do
            patch 'revoquer'
            patch 'remind'
          end
        end

        resources :batch_operations, only: [:create], path: "(:statut)/dossiers", defaults: { statut: 'a-suivre' } do
          collection do
            post 'create_batch_avis' => 'batch_operations#create_batch_avis'
            post 'create_batch_commentaire' => 'batch_operations#create_batch_commentaire'
            post 'batch_instruction_modal/:operation', to: 'batch_operations#batch_instruction_modal', as: :batch_instruction_modal
          end
        end
      end

      #
      # not nested navigation
      #
      resources :dossiers, only: [], param: :dossier_id do
        member do
          get 'telecharger_pjs' => 'dossiers#telecharger_pjs'
          get 'print' => 'dossiers#print'
          patch 'annotations' => 'dossiers#update_annotations'
          get 'annotations/:stable_id', to: 'dossiers#annotation', as: :annotation
          get 'geo_data'
          get 'apercu_attestation'
          get 'bilans_bdf'
        end
      end

      resources :archives, only: [] do
        collection do
          get 'list' => "archives#index"
          post 'create' => "archives#create"
        end
      end

      resources :groupes, only: [:index, :show], controller: 'groupe_instructeurs' do
        resource :contact_information, except: [:show]
        member do
          post 'add_instructeurs'
          delete 'remove_instructeur'
          post 'add_signature'
          get 'preview_attestation_acceptation'
        end
      end

      get 'apercu'
      get 'download_export'
      post 'download_export'
      get 'polling_last_export'
      get 'polling_batch_operation'
      get 'stats'
      get 'exports'
      get 'export_templates'
      get 'notification_preferences'
      get 'administrateurs'
      get 'history', as: :procedure_history
      patch 'update_email_notifications'
      patch 'update_badge_notifications'
      get 'deleted_dossiers'
      get 'email_usagers'
      post 'create_multiple_commentaire_for_brouillons'
    end
  end
end

namespace :instructeurs, defaults: { nav_bar_profile: :instructeur } do
  resources :dossiers, only: [] do
    resources :champs, only: [:edit, :update], param: :public_id
  end
end
