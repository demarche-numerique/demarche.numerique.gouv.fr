# frozen_string_literal: true

#
# Endpoints shared by several profiles (champs, attachments, prefill, data sources)
#

namespace :champs do
  post ':dossier_id/:stable_id/repetition', to: 'repetition#add', as: :repetition
  delete ':dossier_id/:stable_id/repetition', to: 'repetition#remove'

  get ':dossier_id/:stable_id/piece_justificative', to: 'piece_justificative#show', as: :piece_justificative
  put ':dossier_id/:stable_id/piece_justificative', to: 'piece_justificative#update'
  get ':dossier_id/:stable_id/piece_justificative/template', to: 'piece_justificative#template', as: :piece_justificative_template
end

resources :attachments, only: :destroy
resources :recherche, only: [:index]

get "carte", to: "carte#show"

get '/preremplir/:path', to: 'prefill_descriptions#edit', as: :preremplir
get '/preremplir/:path/schema', to: 'api/public/v1/json_description_procedures#show', as: :prefill_json_description, defaults: { format: :json }
resources :procedures, only: [], param: :path do
  member do
    resource :prefill_description, only: :update
    resources :prefill_type_de_champs, only: :show
  end
end

get 'procedures/:id/logo', to: 'procedures#logo', as: :procedure_logo

namespace :data_sources do
  post :referentiel, to: 'referentiel#search', as: :data_source_referentiel
  get :adresse, to: 'adresse#search', as: :data_source_adresse
  get :commune, to: 'commune#search', as: :data_source_commune
  get :education, to: 'education#search', as: :data_source_education

  get :search_domaine_fonct, to: 'chorus#search_domaine_fonct', as: :search_domaine_fonct
  get :search_centre_couts, to: 'chorus#search_centre_couts', as: :search_centre_couts
  get :search_ref_programmation, to: 'chorus#search_ref_programmation', as: :search_ref_programmation
end
