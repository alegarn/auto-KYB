Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    match "client_portal/login/:access_token", to: redirect(status: 307) { |params, req| "#{req.protocol}localhost:#{req.port}/client_portal/login/#{params[:access_token]}" }, via: [ :get, :post ]
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  root "home#index"

  get "countries", to: "countries#index", defaults: { format: :json }

  get "dashboard", to: "dashboard#index"
  get "quickstart", to: "quickstart#index"
  get "auth/loading", to: "auth_loading#show", as: :auth_loading

  resources :forms do
    member do
      get :confirm_delete
      post :duplicate
      post :test_crm_mapping
    end
  end

  resources :clients do
    member do
      get :export
      post :export_to_crm
      get :crm_match_suggestions
      get :crm_contact_details
      post :link_crm_contact
      post :create_crm_contact
    end
  end

  resources :crm_transfers, only: [:index]
  
  namespace :crm do
    resources :imports, only: [:index]
  end
  
  resources :crm_connections, only: [:create, :destroy] do
    collection do
      get "auth/:provider", to: "crm_connections#auth", as: :auth
      get ":provider/callback", to: "crm_connections#callback", as: :callback,
          constraints: { provider: /hubspot|salesforce|zoho/ }
    end
    member do
      post :test
    end
  end

  resources :uploaded_files, only: [ :destroy ] do
    member do
      post :download
    end
  end

  get "settings", to: "settings#index"
  get "settings/auth_setup", to: "settings#auth_setup", as: :auth_setup_settings
  patch "settings/auth_setup", to: "settings#complete_onboarding"

  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_in/:sid", to: "sessions/passwordlesses#edit", as: :passwordless_sign_in
  get  "sign_up", to: "registrations#new"
  get  "registrations/complete", to: "registrations#complete", as: :complete_registration
  delete "sign_up", to: "registrations#destroy"
  resources :sessions, only: [ :index, :show, :destroy ]

  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :oauth_connection,   only: [ :destroy ]
  end

  get "/auth/:provider/callback", to: "sessions#omniauth"

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
    resources :uploaded_files, only: [ :create ]
    get "confirmation", to: "confirmations#show", as: :confirmation
  end

  # Stripe Checkout sessions for subscription flow
  post "checkout_sessions", to: "checkout_sessions#create"
  get  "checkout_sessions/success", to: "checkout_sessions#success", as: :checkout_sessions_success
  get  "checkout_sessions/cancel", to: "checkout_sessions#cancel", as: :checkout_sessions_cancel

  # Subscription required page
  get "subscription/required", to: "subscriptions#required", as: :subscription_required

  # Billing portal endpoint
  post "subscriptions/billing_portal", to: "subscriptions#billing_portal"

  # Stripe webhooks (exempt from authentication/CSRF in controller)
  post "/webhooks/stripe", to: "stripe_webhooks#create"
end
