Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations", sessions: "users/sessions", passwords: "users/passwords" }
  post "csp-reports", to: "csp_reports#create"
  get "up" => "rails/health#show", as: :rails_health_check

  resource :platform_settings, path: "configuracoes", only: [] do
    get :company
    patch :company, action: :update_company
    get :twilio
    patch :twilio, action: :update_twilio
    get :openai
    patch :openai, action: :update_openai
    get :api_token
    post :api_token, action: :create_api_token
    get :lgpd
    patch :lgpd, action: :update_lgpd
  end

  resources :analytics_api_tokens, path: "configuracoes/tokens-bi", only: [ :index, :create, :destroy ]

  resources :privacy_requests, path: "lgpd/solicitacoes", only: [ :index, :create, :update ]
  resources :third_party_operators, path: "lgpd/operadores", only: [ :index, :create, :update, :destroy ]
  resources :privacy_audit_events, path: "lgpd/auditoria", only: [ :index ]

  resources :supplier_imports, path: "dados", only: [ :index, :show, :destroy ] do
    member do
      post :start_validation
      post :sync_status
      post :anonymize_evidence
      get :export_result
      get :privacy_report
    end

    collection do
      get :import
      post :preview_import
      post :create_import
    end
  end

  resources :supplier_discovery_searches, path: "busca", only: [ :index, :create ] do
    collection do
      get :progress
    end
    member do
      get :download_results
      post :create_segment_import
      post :retry_search
    end
  end

  resources :commercial_opportunities, path: "comercial", only: [ :index, :show ] do
    member do
      post :start
      post :sync_status
      get :export
    end
  end

  resources :simulations, path: "simulacoes", only: [ :index, :new, :create, :show ] do
    member do
      get :events
      post :cancel
      post :audio_ticket
    end
  end

  post "empresa/selecionar", to: "account_selections#create", as: :account_selection

  get "equipe", to: "team#index", as: :team
  scope "equipe" do
    resources :team_members, path: "membros", only: [ :update, :destroy ] do
      patch :reactivate, on: :member, path: "reativar"
    end
    resources :team_invitations, path: "convites", only: [ :create, :destroy ] do
      post :resend, on: :member, path: "reenviar"
    end
  end
  get "convites/:token", to: "invitations#show", as: :invitation
  post "convites/:token/aceitar", to: "invitations#accept", as: :accept_invitation

  get "analytics", to: "analytics#overview", as: :analytics
  get "analytics/chamadas", to: "analytics#calls", as: :calls_analytics
  get "analytics/qualificacao", to: "analytics#qualification", as: :qualification_analytics
  get "analytics/lotes", to: "analytics#batches", as: :batches_analytics
  get "analytics/registros", to: "analytics#records", as: :records_analytics
  get "analytics/tentativas", to: "analytics#attempts", as: :attempts_analytics
  get "analytics/exportar", to: "analytics#export", as: :export_analytics, constraints: { format: /xlsx|csv/ }

  # API de Analytics (somente leitura, token de BI da empresa).
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      namespace :mobile do
        resource :session, only: %i[create destroy]
        get :dashboard, to: "dashboard#show"
        get :calls, to: "calls#index"
      end
      namespace :analytics do
        get :summary, to: "summary#show"
        get :records, to: "records#index"
        get :calls, to: "calls#index"
        get :batches, to: "batches#index"
      end
    end
  end

  get "auditoria", to: "validation_audits#index", as: :validation_audits
  post "auditoria/revisoes", to: "validation_audit_reviews#create", as: :validation_audit_reviews

  get "for-devs", to: "developer_docs#show", as: :developer_docs
  post "notificacoes/lidas", to: "notifications#mark_read", as: :mark_notifications_read
  get "termos", to: "pages#terms", as: :terms
  get "privacidade", to: "pages#privacy", as: :privacy

  root "pages#home"
end
