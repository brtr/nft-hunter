require "sidekiq/pro/web"
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  root "nfts#index"

  mount Sidekiq::Web => "/sidekiq"

  resources :nfts, only: [:index, :new, :create, :show] do
    get :purchase_rank, on: :collection
    get :holding_rank, on: :collection
  end

  resources :holding_rank_snap_shots, only: [:index, :show]
end
