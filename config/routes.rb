Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "memories#index"

  resources :memories do
    collection do
      patch :reorder_pinned
    end
    member do
      patch :toggle_pin
      post :generate_embedding
      post :attach_files
      delete "attachments/:attachment_id", to: "memories#purge_attachment", as: :attachment
    end
  end

  namespace :api do
    namespace :v1 do
      get "search", to: "search#index"
      get "openapi", to: "openapi#show", as: :openapi
      get "stats", to: "stats#show"
      post "markdown/render", to: "markdown#render_text"

      resources :memories, except: %i[new edit] do
        collection do
          patch :reorder_pinned
        end
        member do
          patch :toggle_pin
          get :neighbors
          post :generate_embedding
          get :attachments, to: "memory_attachments#index"
          post :attachments, to: "memory_attachments#create"
          delete "attachments/:attachment_id", to: "memory_attachments#destroy", as: :attachment
        end
      end
    end
  end
end
