Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  root "home#index"

  # Countries list endpoint (serves config/countries.yml)
  get "countries", to: "countries#index", defaults: { format: :json }

  get "dashboard", to: "dashboard#index"

  resources :forms do
    member do
      get :confirm_delete
    end
  end

  resources :clients do
    member do
      get :export
    end
  end

  get "settings", to: "settings#index"

  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [ :index, :show, :destroy ]
  resource  :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

  get "inertia-example", to: "inertia_example#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  # Client portal (Phase 0) - placeholder routes
  resources :client_forms, only: [ :create, :show, :destroy ] do
      member do
        get :password_reveal
        get :export_responses
      end
    end

  namespace :client_portal do
    get  "login/:access_token", to: "sessions#new", as: :login
    post "login/:access_token", to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resource :form_response, only: [ :show, :update ]
    get "confirmation", to: "confirmations#show", as: :confirmation
  end
end
