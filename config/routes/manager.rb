# frozen_string_literal: true

namespace :manager do
  resources :procedures, only: [:index, :show, :edit, :update] do
    member do
      post :whitelist
      post :hide_as_template
      post :unhide_as_template
      post :discard
      post :restore
      put :delete_administrateur
      post :add_administrateur_and_instructeur
      post :add_administrateur_with_confirmation
      post :change_piece_justificative_template
      patch :add_tags
      patch :update_template_status
      get :export_mail_brouillons
    end

    resources :confirmation_urls, only: :new
    resources :administrateur_confirmations, only: [:new, :create]
  end

  resources :procedure_tags

  resources :banners, only: [:index, :update]

  resources :archives, only: [:index, :show]

  resources :dossiers, only: [:index, :show] do
    member do
      get :transfer_edit
      post :transfer
      delete :transfer_destroy
    end
  end

  resources :groupe_instructeurs, only: [:index, :show]

  resources :administrateurs, only: [:index, :show, :new, :create] do
    member do
      post :reinvite
      delete :delete
    end
  end

  resources :users, only: [:index, :show, :edit, :update] do
    member do
      delete :delete
      post :resend_confirmation_instructions
      post :resend_reset_password_instructions
      post :unblock_mails
      put :enable_feature
      get :emails
      put :reactivate
    end
    put 'unblock_email'
  end

  resources :experts, only: [:index, :show]

  resources :instructeurs, only: [:index, :show, :edit, :update] do
    member do
      post :reinvite
      delete :delete
    end
  end

  if ENV['ADMINS_GROUP_ENABLED'] == 'enabled' || Rails.env.test? # can be removed if needed when EVERY PARTS of the feature will be merged / from env.example.optional
    resources :gestionnaires, only: [:index, :show, :edit, :update] do
      delete :delete, on: :member
    end

    resources :groupe_gestionnaires, path: 'groupe_administrateurs', only: [:index, :show, :new, :create, :edit, :update] do
      member do
        post :add_gestionnaire
        delete :remove_gestionnaire
      end
    end
  end

  resources :bill_signatures, only: [:index]

  resources :exports, only: [:index, :show]

  resources :services, only: [:index, :show]

  resources :super_admins, only: [:index, :show, :destroy] do
    member do
      get :reset_otp_edit
      post :reset_otp
    end
  end

  resources :zones, only: [:index, :show]

  resources :team_accounts, only: [:index, :show]

  resources :email_events, only: [:index, :show]

  resources :dubious_procedures, only: [:index]
  resources :published_procedures, only: [:index]
  resources :safe_mailers
  resources :top_activity_procedures, only: [:index]

  # Mounted engines bypass Manager::ApplicationController, so the OTP enrollment
  # gate (RequiresEnrolledSuperAdminOtp) has to be re-applied here.
  authenticate :super_admin, -> (super_admin) { !SUPER_ADMIN_OTP_ENABLED || super_admin.otp_required_for_login? } do
    mount Flipper::UI.app(-> { Flipper.instance }) => "/features", as: :flipper
    mount MaintenanceTasks::Engine => "/maintenance_tasks"
    mount Sidekiq::Web => "/sidekiq"
  end

  get 'data_exports' => 'administrateurs#data_exports'
  get 'exports/administrateurs/last_half_year' => 'administrateurs#export_last_half_year'
  get 'exports/instructeurs/last_half_year' => 'instructeurs#export_last_half_year'
  get 'exports/administrateurs/with_publiee_procedure' => 'administrateurs#export_with_publiee_procedure'
  get 'exports/instructeurs/currently_active' => 'instructeurs#export_currently_active'

  get 'import_procedure_tags' => 'procedures#import_data'
  post 'import_tags' => 'procedures#import_tags'
  root to: "administrateurs#index"
end
