Rails.application.routes.draw do
  root "nfts#index"

  resources :nfts, only: [:index, :show]
end
