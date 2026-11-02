# frozen_string_literal: true

#
# Monitoring
#

get "/ping" => "ping#index"

if Rails.env.development?
  mount LetterOpenerWeb::Engine, at: "/letter_opener"
end

#
# Main pages
#

root 'root#index'
get '/administration' => 'root#administration'

get 'admin' => 'admin#index'

get '/stats' => 'stats#index'
get '/stats/download' => 'stats#download'

get "patron" => "root#patron" if Rails.env.local?
get "suivi" => "root#suivi"
post "save_locale" => "root#save_locale"

get "contact", to: "contact#index"
post "contact", to: "contact#create"

get "contact-admin", to: "contact#admin"

get "mentions-legales", to: "static_pages#legal_notice"
get "declaration-accessibilite", to: "static_pages#accessibility_statement"

post "webhooks/crisp", to: "webhook#crisp"
post "webhooks/brevo", to: "webhook#brevo"

resources :release_notes, only: [:index]

resources :faq, only: [:index]
get '/faq/:category/:slug', to: 'faq#show', as: :faq

#
# Errors
#

get '/404', to: 'errors#not_found'
get '/422', to: 'errors#unprocessable_entity'
get '/500', to: 'errors#internal_server_error'
get '/:status', to: 'errors#show', constraints: { status: /[4-5][0-5]\d/ }

#
# Test-only endpoints
#

if Rails.env.test?
  scope 'test/api_geo' do
    get 'regions' => 'api_geo_test#regions'
    get 'communes' => 'api_geo_test#communes'
    get 'departements' => 'api_geo_test#departements'
    get 'departements/:code/communes' => 'api_geo_test#communes'
  end
end

#
# Legacy routes
#

get 'demandes/new' => redirect(DEMANDE_INSCRIPTION_ADMIN_PAGE_URL)

get 'backoffice' => redirect('/procedures')
get 'backoffice/sign_in' => redirect('/users/sign_in')
get 'backoffice/dossiers/procedure/:procedure_id' => redirect('/procedures/%{procedure_id}')
