# frozen_string_literal: true

devise_for :users, controllers: {
  sessions: 'users/sessions',
  registrations: 'users/registrations',
  confirmations: 'users/confirmations',
  passwords: 'users/passwords',
}

devise_scope :user do
  get '/users/no_procedure' => 'users/sessions#no_procedure'
  get 'connexion-par-jeton/:id' => 'users/sessions#sign_in_by_link', as: 'sign_in_by_link'
  get 'lien-envoye' => 'users/sessions#link_sent', as: 'link_sent'
  post '/instructeurs/reset-link-sent' => 'users/sessions#reset_link_sent'
  get '/users/password/reset-link-sent' => 'users/passwords#reset_link_sent'
  get 'logout' => 'users/sessions#logout'
end

post 'password_complexity' => 'password_complexity#show', as: 'show_password_complexity'
post 'check_email' => 'email_checker#show', as: 'show_email_suggestions'

resources :targeted_user_links, only: [:show]

# Omniauth
get 'auth/:provider/callback', to: 'rdv_service_public/oauth#callback'

scope 'france_connect', as: :france_connect, controller: :france_connect do
  get '/' => :login
  get 'callback'
  post 'send_email_merge_request'
  get 'merge_using_email_link/:email_merge_token' => :merge_using_email_link, as: :merge_using_email_link
  post 'merge_using_fc_email'
  post 'merge_using_password'
  get 'confirm_email/:token' => :confirm_email, as: :confirm_email

  # to be migrated
  get 'particulier/merge_using_email_link/:email_merge_token' => :merge_using_email_link

  get 'redirect_uris'
end

get 'pro_connect' => 'pro_connect#index'
get 'pro_connect/login' => 'pro_connect#login'
get 'pro_connect/callback' => 'pro_connect#callback'
get 'pro_connect/required' => 'pro_connect#required'

scope 'pro_connect/migration', as: :pro_connect_migration, controller: :pro_connect_migrations do
  get '/' => :show
  get 'support'
  get 'code'
  post 'code' => :verify_code
  post 'resend_code'
  get 'completed'
end
