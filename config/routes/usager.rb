# frozen_string_literal: true

#
# Deprecated UI
#

namespace :users, defaults: { nav_bar_profile: :user } do
  resources :dossiers, only: [] do
    post '/repousser-expiration' => 'dossiers#extend_conservation'
    post '/repousser-expiration-and-restore' => 'dossiers#extend_conservation_and_restore'
  end

  # Redirection of legacy "/users/dossiers" route to "/dossiers"
  get 'dossiers', to: redirect('/dossiers')
  get 'dossiers/:id/recapitulatif', to: redirect('/dossiers/%{id}')
  get 'dossiers/invites/:id', to: redirect(path: '/invites/%{id}')

  get 'activate' => '/users/activate#new'
  patch 'activate' => '/users/activate#create'
  get 'confirm_email/:token' => '/users/activate#confirm_email', as: :confirm_email
  post 'resend_verification_email', to: '/users/activate#resend_verification_email', as: :resend_confirmation_email
end

resources :invites, only: [:show, :destroy] do
  collection do
    post 'dossier/:dossier_id', to: 'invites#create', as: :dossier
    get 'dossier/:dossier_id/invites', to: 'invites#index', as: :dossier_index
  end
end

#
# Current UI
#

scope module: 'users', defaults: { nav_bar_profile: :user } do
  namespace :statistiques do
    get '/:path', action: 'statistiques'
  end

  namespace :commencer do
    get '/test/:path/dossier_vide', action: :dossier_vide_pdf_test, as: :dossier_vide_test
    get '/test/:path', action: 'commencer_test', as: :test
    get '/:path', action: 'commencer'
    get '/:path/dossier_vide', action: 'dossier_vide_pdf', as: :dossier_vide
    get '/:path/sign_in', action: 'sign_in', as: :sign_in
    get '/:path/sign_up', action: 'sign_up', as: :sign_up
    get '/:path/france_connect', action: 'france_connect', as: :france_connect
    get '/:path/pro_connect', action: 'pro_connect', as: :pro_connect
  end

  resources :dossiers, only: [:index, :show, :destroy, :new] do
    member do
      get 'identite'
      patch 'identite'
      patch 'update_identite'
      post 'clone'
      get 'siret'
      post 'siret', to: 'dossiers#update_siret'
      get 'etablissement'
      get 'brouillon'
      patch 'brouillon', to: 'dossiers#update'
      post 'brouillon', to: 'dossiers#submit_brouillon'
      get 'modifier', to: 'dossiers#modifier'
      post 'modifier', to: 'dossiers#submit_en_construction'
      post 'check_completude', to: 'dossiers#check_completude'
      post 'notify_owner_for_changes', to: 'dossiers#notify_owner_for_changes'
      get 'champs/:stable_id', to: 'dossiers#champ', as: :champ
      patch 'champs/:stable_id/revert_prefill', to: 'dossiers#revert_prefill', as: :revert_prefill_champ
      get 'merci'
      get 'demande'
      get 'messagerie'
      get 'rendez-vous'
      post 'commentaire' => 'dossiers#create_commentaire'
      patch 'restore', to: 'dossiers#restore'
      get 'attestation'
      get 'transferer', to: 'dossiers#transferer'
      post 'transferer', to: 'transfers#create', as: :transfer
      get 'attestation_depot', format: :pdf
      get 'papertrail', to: 'dossiers#attestation_depot', format: :pdf
      post 'set_accuse_lecture_agreement_at'
      get 'corbeille', to: 'dossiers#show_in_trash'
      get 'supprime', to: 'dossiers#show_deleted'
    end

    collection do
      resources :transfers, only: [:update, :destroy]
    end
  end

  get 'deleted_dossiers' => 'dossiers#deleted_dossiers'
  get 'corbeille', to: 'dossiers#trash', as: :trash
  get 'transferts' => 'dossiers#transfer_requests'
  get 'personnalisation', to: 'dossiers#personnalisation', as: :personnalisation
  patch 'personnalisation', to: 'dossiers#update_personnalisation'

  get 'profil' => 'profil#show'
  get 'profil/mot-de-passe' => 'profil_passwords#edit', as: :edit_profil_password
  patch 'profil/mot-de-passe' => 'profil_passwords#update', as: :profil_password
  post 'profil/mot-de-passe/oubli' => 'profil_passwords#forgot', as: :forgot_profil_password
  patch 'update_email' => 'profil#update_email'
  post 'transfer_all_dossiers' => 'profil#transfer_all_dossiers'
  post 'accept_merge' => 'profil#accept_merge'
  post 'refuse_merge' => 'profil#refuse_merge'
  delete 'france_connect_information' => 'profil#destroy_fci'
  patch 'preferred_domain', to: 'profil#preferred_domain'
  get 'fermeture/:path', to: 'commencer#closing_details', as: :closing_details
  get 'introuvable/:path', to: 'commencer#not_found', as: :not_found
end

#
# Dossier recovery (support flow)
#

resource :recovery, only: [], path: :recuperation_de_dossiers do
  collection do
    get :nature
    post :nature, action: :post_nature
    get :identification
    post :identification, action: :post_identification
    get :selection
    post :selection, action: :post_selection
    get :terminee
    get :support
  end

  root action: :nature
end
