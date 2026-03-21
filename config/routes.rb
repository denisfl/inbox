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

      # Nested routes for blocks (deprecated — replaced by Lexxy rich text editor)
      # resources :blocks, only: [ :create, :update, :destroy ] do
      #   collection do
      #     post :reorder
      #   end
      #
      #   # Upload routes for blocks
      #   member do
      #     post :upload_image, controller: "uploads"
      #     post :upload_file, controller: "uploads"
      #   end
      # end

      # Document tag management
      resources :tags, only: [ :create, :destroy ], param: :name, controller: "document_tags"

      # Document-specific actions
      member do
        post :classify
        post :extract_tags
        post :upload
        post :transcribe
        get  :preview
        get "export/:format", to: "documents#export", as: :export
      end
    end

    # Task tag management
    resources :tasks, only: [] do
      resources :tags, only: [ :create, :destroy ], param: :name, controller: "task_tags"
    end

    # Calendar event tag management
    resources :calendar_events, only: [] do
      resources :tags, only: [ :create, :destroy ], param: :name, controller: "calendar_event_tags"
    end

    # Tag autocomplete
    resources :tags, only: [ :index ]

    # Search endpoint
    get "documents/search", to: "documents#search", as: :search_documents

    # Telegram webhook
    post "telegram/webhook", to: "telegram#webhook"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Web UI routes
  resources :documents, only: [ :index, :show, :edit, :new, :update, :destroy ] do
    member do
      patch :toggle_pinned
      patch :update_status
      get :export
    end
    collection do
      post :bulk_upload
      get :search
      get :inbox
    end
  end

  # Calendar (Agenda + mini-month)
  get "/calendar",        to: "calendars#index",  as: :calendar
  get "/calendar/widget", to: "calendars#widget", as: :calendar_widget

  # Calendar events (manual creation + iCal import)
  resources :calendar_events, only: [ :new, :create, :edit, :update, :destroy ], path: "calendar/events"
  post "/calendar/import", to: "calendar_events#import_ical", as: :import_ical

  # Tasks
  resources :tasks, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member do
      patch :toggle
    end
  end

  # Tags
  resources :tags, only: [ :index, :show ], param: :name

  # Shortcut for creating new document
  get "/new", to: "documents#new", as: :new_note

  # Dashboard
  get "/dashboard", to: "dashboard#index", as: :dashboard
  post "/quick_capture", to: "dashboard#quick_capture", as: :quick_capture

  # Root path — Dashboard
  root "dashboard#index"
end
