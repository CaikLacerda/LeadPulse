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
  end

  resources :supplier_imports, path: "dados", only: [:index, :destroy] do
    member do
      post :start_validation
      post :sync_status
      get :export_result
    end

    collection do
      get :export
      get :import
      post :preview_import
      post :create_import
    end
  end

  resources :supplier_discovery_searches, path: "busca", only: [:index, :create] do
    member do
      get :download_results
      post :create_segment_import
    end
  end

  get "auditoria", to: "validation_audits#index", as: :validation_audits

  get 'for-devs', to: 'developer_docs#show', as: :developer_docs

  root "pages#home"
end
