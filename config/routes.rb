Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API namespace
  namespace :api do
    resources :documents do
      # Collection-level search
      collection do
        get :search
      end

      # Nested routes for blocks
      resources :blocks, only: [:create, :update, :destroy] do
        collection do
          post :reorder
        end

        # Upload routes for blocks
        member do
          post :upload_image, controller: 'uploads'
          post :upload_file, controller: 'uploads'
        end
      end

      # Document-specific actions
      member do
        post :classify
        post :extract_tags
        post :upload
        get  :preview
        get 'export/:format', to: 'documents#export', as: :export
      end
    end

    # Search endpoint
    get 'documents/search', to: 'documents#search', as: :search_documents

    # Telegram webhook
    post 'telegram/webhook', to: 'telegram#webhook'
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Web UI routes
  resources :documents, only: [:index, :show, :edit, :new]

  # Calendar (Agenda + mini-month)
  get "/calendar",        to: "calendars#index",  as: :calendar
  get "/calendar/widget", to: "calendars#widget", as: :calendar_widget

  # Shortcut for creating new document
  get '/new', to: 'documents#new', as: :new_note

  # Root path
  root "documents#index"
end
