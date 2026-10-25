Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: %i[index create]
      patch "users/:id", to: "users#update", as: :user
    end
  end
end
