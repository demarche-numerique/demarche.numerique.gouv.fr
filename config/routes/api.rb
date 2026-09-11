# frozen_string_literal: true

get 'graphql/schema' => redirect('/graphql/schema/index.html')
# Le playground servi ici a été retiré : on oriente vers la doc expliquant comment interroger l'API avec un client GraphQL.
get 'graphql' => redirect(API_GRAPHQL_CLIENT_DOC_URL, status: 302)

namespace :api do
  namespace :v1 do
    resources :procedures, only: [:show] do
      resources :dossiers, only: [:index, :show]
    end
  end

  namespace :v2 do
    post :graphql, to: "graphql#execute"
    get 'dossiers/pdf/:id', format: :pdf, to: "dossiers#pdf", as: :dossier_pdf
    get 'dossiers/geojson/:id', to: "dossiers#geojson", as: :dossier_geojson
  end

  namespace :public do
    namespace :v1 do
      resources :demarches, only: [] do
        member do
          resources :dossiers, only: [:create, :index]
          resources :stats, only: :index
        end
      end
    end
  end
end
