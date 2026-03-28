Rails.application.routes.draw do
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check

  resources :supplier_imports, path: "dados", only: [:index] do
    collection do
      get  :export
      get  :import
      post :create_import
    end
  end

  root "pages#home"
end
