Rails.application.routes.draw do
  # =============================================================================
  # API Documentation (Rswag/Swagger)
  # =============================================================================
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # =============================================================================
  # Health Check
  # =============================================================================
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # =============================================================================
  # Feature Flags (Flipper UI) - Development Only
  # =============================================================================
  # Access at: http://localhost:3000/flipper
  # TODO: Add authentication before enabling in production!
  if Rails.env.development?
    mount Flipper::UI.app(Flipper) => '/flipper'
  end

  # =============================================================================
  # API Routes (v1)
  # =============================================================================
  namespace :api do
    namespace :v1 do
      # Test endpoint
      get 'ping', to: 'ping#index'

      # Authentication routes (will be created later)
      # namespace :auth do
      #   post 'register'
      #   post 'login'
      #   delete 'logout'
      #   post 'refresh'
      #   get 'me'
      # end

      # Resource routes (will be created later)
      # resources :users, only: [:index, :show, :update, :destroy]
      # resources :conversations, only: [:index, :show, :create, :destroy] do
      #   resources :messages, only: [:index, :create]
      # end
    end
  end

  # =============================================================================
  # Admin Panel (ActiveAdmin) - Will be added when you run rails g active_admin:install
  # =============================================================================
  # Access at: http://localhost:3000/admin
  # Note: ActiveAdmin generates its own routes automatically
end
