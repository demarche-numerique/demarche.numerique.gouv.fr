# frozen_string_literal: true

# order matters: we don't want those routes to match /admin/procedures/:id
get 'admin/procedures/new' => 'administrateurs/procedures#new', as: :new_admin_procedure, defaults: { nav_bar_profile: :administrateur }

namespace :admin do
  get 'activate' => '/users/activate#new'
  patch 'activate' => '/users/activate#create'
  get 'procedures/archived', to: redirect('/admin/procedures?statut=archivees')
  get 'procedures/draft', to: redirect('/admin/procedures?statut=brouillons')
end

scope module: 'administrateurs', path: 'admin', as: 'admin', defaults: { nav_bar_profile: :administrateur } do
  resources :procedures do
    resources :archives, only: [:index, :create]
    resources :exports, only: [] do
      collection do
        get 'download'
        post 'download'
      end
    end

    collection do
      get 'new_from_existing'
      post 'search'
      get 'all' if Rails.application.config.ds_zonage_enabled
      get 'administrateurs' if Rails.application.config.ds_zonage_enabled
      get 'select_procedure'
    end

    member do
      post 'detail'
      get 'apercu'
      get 'champs'
      get 'zones'
      get 'annotations'
      get 'modifications'
      get 'parcours'
      get 'monavis'
      patch 'update_monavis'
      get 'accuse_lecture'
      patch 'update_accuse_lecture'
      get 'rdv'
      patch 'rdv', to: 'procedures#update_rdv'
      get 'pro_connect_restricted'
      patch 'pro_connect_restricted', to: 'procedures#update_pro_connect_restricted'
      put :allow_expert_review
      put :allow_expert_messaging
      put :experts_require_administrateur_invitation
      put :restore
      get 'api_champ_columns'
      get 'commune_info'
    end

    get 'jetons', to: 'jetons#index'

    resource :jetons, only: [], controller: 'jetons' do
      get 'api_particulier', action: :edit_particulier
      patch 'api_particulier', action: :update_particulier
      delete 'api_particulier', action: :destroy_particulier

      get 'api_entreprise', action: :edit_entreprise
      patch 'api_entreprise', action: :update_entreprise
      delete 'api_entreprise', action: :destroy_entreprise
    end

    resources :conditions, only: [:update, :destroy], param: :stable_id do
      member do
        patch :add_row
        patch :change_targeted_champ
        delete :delete_row
      end
    end

    resources :routing_rules, only: [:update], param: :groupe_instructeur_id do
      member do
        patch :add_row
        patch :change_targeted_champ
        delete :delete_row
      end
    end

    resource :ineligibilite_rules, only: [:edit, :update], param: :revision_id do
      member do
        patch :change_targeted_champ
        patch :add_row
        delete :delete_row
      end
      patch :change
    end

    patch :update_defaut_groupe_instructeur, controller: 'routing_rules', as: :update_defaut_groupe_instructeur

    get 'clone_settings'
    post 'clone'
    put 'archive'
    get 'publication' => 'procedures#publication', as: :publication
    post 'check_path' => 'procedures#check_path', as: :check_path
    # TODO remove in next release
    get 'check_path' => 'procedures#check_path'
    get 'path'
    patch 'path', to: 'procedures#update_path', as: :update_path
    put 'publish' => 'procedures#publish', as: :publish
    put 'reset_draft' => 'procedures#reset_draft', as: :reset_draft
    put 'publish_revision' => 'procedures#publish_revision', as: :publish_revision
    get 'transfert' => 'procedures#transfert', as: :transfert
    get 'close' => 'procedures#close', as: :close
    get 'closing_notification' => 'procedures#closing_notification', as: :closing_notification
    post 'notify_after_closing' => 'procedures#notify_after_closing', as: :notify_after_closing
    get 'confirmation' => 'procedures#confirmation', as: :confirmation
    post 'transfer' => 'procedures#transfer', as: :transfer
    resources :email_templates, only: [:edit, :update, :show]

    resources :groupe_instructeurs, only: [:index, :show, :create, :update, :destroy] do
      patch 'update_state' => 'groupe_instructeurs#update_state'
      resource :contact_information, only: [:new, :create, :edit, :update, :destroy]

      member do
        post 'add_instructeurs'
        delete 'remove_instructeur'
        get 'reaffecter_dossiers'
        post 'reaffecter'
        post 'add_signature'
        get 'preview_attestation_acceptation'
      end

      collection do
        get 'options'
        patch 'wizard'
        get 'simple_routing'
        post 'create_simple_routing'
        delete 'destroy_all_groups_but_defaut'
        patch 'update_instructeurs_self_management_enabled'
        patch 'update_instructeurs_can_edit_dossiers'
        post 'import'
        get 'export_groupe_instructeurs'
        get 'export_contact_informations'
        post 'import_contact_informations'
        post 'bulk_route'
        post 'add_instructeur_to_all_groupes'
        delete 'remove_instructeur_from_all_groupes'
      end
    end

    resources :administrateurs, controller: 'procedure_administrateurs', only: [:index, :create, :destroy]

    resources :experts, controller: 'experts_procedures', only: [:index, :create, :update, :destroy]

    resources :types_de_champ, only: [:create, :update, :destroy], param: :stable_id do
      member do
        patch :move_and_morph
        patch :move_up
        patch :move_down
        put :piece_justificative_template
        put :notice_explicative
        delete :nullify_referentiel
      end

      collection do
        # Entry point for Simpliscore workflow
        get 'simplify/new', action: :new_simplify, as: :new_simplify

        # Routes with explicit tunnel_id
        get 'simplify/:tunnel_id/:rule',
          action: :simplify,
          as: :simplify,
          constraints: { rule: /#{LLMRuleSuggestion.rules.keys.join('|')}/ }

        get 'simplify/:tunnel_id/:rule/poll',
          action: :poll_simplify,
          as: :poll_simplify,
          constraints: { rule: /#{LLMRuleSuggestion.rules.keys.join('|')}/ }

        post 'simplify/:tunnel_id/:rule/enqueue',
          action: :enqueue_simplify,
          as: :enqueue_simplify,
          constraints: { rule: /#{LLMRuleSuggestion.rules.keys.join('|')}/ }

        post 'simplify/:tunnel_id/:rule/accept/:id',
          action: :accept_simplification,
          as: :accept_simplification,
          constraints: { rule: /#{LLMRuleSuggestion.rules.keys.join('|')}/ }
      end
    end

    resources :email_templates, only: [:index] do
      member do
        get 'preview'
        post 'preview'
      end
    end

    # Kept for a while so an admin who had the editor open when the deploy landed
    # can still work, and bookmarked links keep working. Drop the block with
    # Emails::LEGACY_SLUGS.
    legacy_email_template = -> (suffix) do
      -> (params, _) { "/admin/procedures/#{params[:procedure_id]}/email_templates/#{Emails::LEGACY_SLUGS.fetch(params[:id])}#{suffix}" }
    end
    # The block form of redirect interpolates raw, unlike the string form: without
    # these constraints a procedure_id holding a space or a CRLF would reach
    # URI.parse and raise.
    legacy_ids = { procedure_id: /\d+/, id: Regexp.union(Emails::LEGACY_SLUGS.keys) }

    get 'mail_templates' => redirect('/admin/procedures/%{procedure_id}/email_templates')
    get 'mail_templates/:id' => redirect(legacy_email_template.call('/edit')), constraints: legacy_ids
    get 'mail_templates/:id/edit' => redirect(legacy_email_template.call('/edit')), constraints: legacy_ids
    get 'mail_templates/:id/preview' => redirect(legacy_email_template.call('/preview')), constraints: legacy_ids

    # What that editor posts is served in place rather than redirected: the CSRF
    # token of a form is an HMAC of the path it was rendered for, so a redirect —
    # even a 308, which does replay the method and the body — would arrive on the
    # new path and be rejected with a 403, losing what the admin had typed.
    match 'mail_templates/:id' => 'email_templates#update', via: [:put, :patch], constraints: legacy_ids
    post 'mail_templates/:id/preview' => 'email_templates#preview', constraints: legacy_ids

    resources :labels, controller: 'labels', except: [:show] do
      collection do
        get 'order_positions'
        patch 'update_order_positions'
      end
    end

    resource :attestation_template, only: [:show, :edit, :update, :create] do
      get 'preview', on: :member
    end

    resource :chorus, only: [:edit, :update] do
      get 'add_champ_engagement_juridique'
    end

    resource :attestation_template_v2, only: [:show, :edit, :update, :create] do
      post :reset
    end

    resources :referentiels, only: [:new, :create, :edit, :update], path: ':stable_id', constraints: { stable_id: /\d+/ } do
      collection do
        patch :validate_url
        post :validate_url
      end
      member do
        get :configuration_error
        patch :update_autocomplete_configuration
        get :autocomplete_configuration
        get :mapping_type_de_champ
        patch :update_mapping_type_de_champ
        patch :update_prefill_and_display_type_de_champ
        get :prefill_and_display
        delete :reset_mapping
      end
    end

    resource :dossier_submitted_message, only: [:edit, :update, :create] do
      post :preview, on: :member
    end
    # ADDED TO ACCESS IT FROM THE IFRAME
    get 'attestation_template/preview' => 'attestation_templates#preview'

    resource :sva_svr, only: [:show, :edit, :update], controller: 'sva_svr'
  end

  get 'mon-groupe' => 'groupe_gestionnaire#show', as: :groupe_gestionnaire
  get 'mon-groupe/administrateurs' => 'groupe_gestionnaire#administrateurs', as: :groupe_gestionnaire_administrateurs
  get 'mon-groupe/gestionnaires' => 'groupe_gestionnaire#gestionnaires', as: :groupe_gestionnaire_gestionnaires
  get 'mon-groupe/commentaires' => 'groupe_gestionnaire#commentaires', as: :groupe_gestionnaire_commentaires
  post 'mon-groupe/create_commentaire' => 'groupe_gestionnaire#create_commentaire', as: :groupe_gestionnaire_create_commentaire

  resources :services, except: [:show] do
    collection do
      patch 'add_to_procedure'
      get ':procedure_id/prefill' => :prefill, as: :prefill
    end
  end

  resources :api_tokens, only: [:create, :destroy, :edit, :update] do
    member do
      delete 'remove_procedure'
    end
    collection do
      get :nom
      get :autorisations
      get :securite
    end
  end
end
