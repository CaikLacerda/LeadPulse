Rails.application.routes.draw do
  devise_for :users
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

  resources :privacy_requests, path: "lgpd/solicitacoes", only: [:index, :create, :update]
  resources :third_party_operators, path: "lgpd/operadores", only: [:index, :create, :update, :destroy]
  resources :privacy_audit_events, path: "lgpd/auditoria", only: [:index]

  resources :supplier_imports, path: "dados", only: [:index, :show, :destroy] do
    member do
      post :start_validation
      post :sync_status
      post :anonymize_evidence
      get :export_result
      get :privacy_report
    end

    collection do
      get :export
      get :import
      post :preview_import
      post :create_import
      get :academic_report
    end
  end

  resources :supplier_discovery_searches, path: "busca", only: [:index, :create] do
    member do
      get :download_results
      post :create_segment_import
    end
  end

  get "auditoria", to: "validation_audits#index", as: :validation_audits
  post "auditoria/revisoes", to: "validation_audit_reviews#create", as: :validation_audit_reviews

  get 'for-devs', to: 'developer_docs#show', as: :developer_docs

  root "pages#home"
end
