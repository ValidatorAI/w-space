Rails.application.routes.draw do
  root "welcome#show"

  resource :first_run

  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

  resource :account do
    scope module: "accounts" do
      resources :users do
        member do
          patch :activate
        end
      end

      resources :bots do
        scope module: "bots" do
          resource :key, only: :update
        end
      end

      resource :join_code, only: :create
      resource :logo, only: %i[ show destroy ]
      resource :custom_styles, only: %i[ edit update ]
    end
  end

  direct :fresh_account_logo do |options|
    account = Current.account
    version = account&.logo&.attachment&.blob&.key || account&.updated_at&.to_fs(:number)
    route_for :account_logo, v: version, size: options[:size]
  end

  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"

  resources :qr_code, only: :show

  resources :attention_items, only: %i[ update ] do
    member do
      patch :resolve
      patch :dismiss
    end
  end

  resources :approval_requests, only: %i[ show update ] do
    member do
      patch :approve
      patch :confirm
      patch :deny
      patch :cancel
    end
  end

  resources :users, only: :show do
    scope module: "users" do
      resource :avatar, only: %i[ show destroy ]
      resource :ban, only: %i[ create destroy ]

      scope defaults: { user_id: "me" } do
        resource :sidebar, only: :show
        resource :profile
        resource :settings, only: :show
        get "company/home", to: "companies#home", as: :company_home
        get "company/status", to: "companies#status", as: :company_status
        get "company/settings", to: "companies#settings", as: :company_settings
        get "company/settings/add-user", to: "companies#add_user", as: :company_add_user
        patch "company/settings", to: "companies#update", as: :update_company_settings
        get "company/projects/new", to: "projects#new", as: :company_project_new
        post "company/projects", to: "projects#create", as: :company_projects
        get "company/projects/:id/overview", to: "projects#overview", as: :company_project_overview
        get "company/projects/:id/status", to: "projects#status", as: :company_project_status
        patch "company/projects/:project_id/todos/:id/toggle", to: "projects/todos#toggle", as: :company_project_todo_toggle
        patch "company/projects/:project_id/action_items/:id/toggle", to: "projects/action_items#toggle", as: :company_project_action_item_toggle
        get "company/projects/:id/all-hands", to: "projects#all_hands", as: :company_project_all_hands
        get "company/projects/:id/knowledge", to: "projects#knowledge", as: :company_project_knowledge
        get "company/projects/:id/knowledge/file", to: "projects#knowledge_file", as: :company_project_knowledge_file
        resources :push_subscriptions do
          scope module: "push_subscriptions" do
            resources :test_notifications, only: :create
          end
        end
      end
    end
  end

  namespace :autocompletable do
    resources :users, only: :index
  end

  direct :fresh_user_avatar do |user, options|
    route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:number)
  end

  resources :rooms do
    resources :messages

    post ":bot_key/messages", to: "messages/by_bots#create", as: :bot_messages

    scope module: "rooms" do
      resource :refresh, only: :show
      resource :settings, only: %i[ show update ]
      resource :involvement, only: %i[ show update ]
      resource :clear, only: :create
    end

    get "@:message_id", to: "rooms#show", as: :at_message
  end

  namespace :rooms do
    resources :opens
    resources :closeds
    resources :directs
    resources :projects, only: %i[ edit update ] do
      resource :users_settings, only: %i[ show update ], controller: "projects/users_settings"
    end
  end

  get "pooling_messages", to: "messages#last_messages", as: :pooling_messages

  resources :messages do
    scope module: "messages" do
      resources :boosts
    end
  end

  resources :searches, only: %i[ index create ] do
    delete :clear, on: :collection
  end

  resource :unfurl_link, only: :create

  get "webmanifest"    => "pwa#manifest"
  get "service-worker" => "pwa#service_worker"

  namespace :api do
    get "company_status_periods/by_slug/:slug", to: "company_status_periods#by_slug", as: :by_slug_api_company_status_periods
    get "company_status_periods/by_name", to: "company_status_periods#by_name", as: :name_api_company_status_periods

    resources :rooms, only: %i[ index show ] do
      resources :messages, only: %i[ index show create update destroy ] do
        get :attachment, on: :member
      end
      resources :actions, only: :create
      resources :decisions, only: :create
      get :threads, on: :member
      get :search, on: :collection
    end

    resources :projects, only: %i[ index show ] do
      resources :rooms, only: %i[ index show ] do
        resources :messages, only: %i[ index show create update destroy ] do
          get :attachment, on: :member
        end
        resources :actions, only: :create
        resources :decisions, only: :create
        get :threads, on: :member
        get :search, on: :collection
      end
    end

    resources :attention_items, only: %i[ index show create update destroy ]

    # Flat routes since message ids are globally unique; no project/room scoping required.
    resources :messages, only: %i[ show update destroy ] do
      get :attachment, on: :member
    end

    resources :company_status_periods, only: %i[ index show create update destroy ] do
      get :current, on: :collection
    end

    resources :company_status_items, only: %i[ index show create update destroy ] do
      get :by_period, on: :collection
      get :advanced_filter, on: :collection
    end

    resources :projects, only: [] do
      resources :project_users, only: %i[ index show ], path: "users"
      resources :project_all_hands_takeaways, only: %i[ index show create update destroy ]
      resources :project_all_hands_decisions, only: %i[ index show create update destroy ]
      resources :project_all_hands_action_items, only: %i[ index show create update destroy ]
      resources :project_knowledge_items, only: %i[ index show create update destroy ]
      resources :knowledge_items, only: %i[ index show create update destroy ], controller: "project_knowledge_items"
      resources :project_external_assets, only: %i[ index show create update destroy ]
      resources :external_assets, only: %i[ index show create update destroy ], controller: "project_external_assets"
      resources :project_adrs, only: %i[ index show create update destroy ]
      resources :adrs, only: %i[ index show create update destroy ], controller: "project_adrs"
      resources :project_knowledge_activities, only: %i[ index show create update destroy ]
      resources :knowledge_activities, only: %i[ index show create update destroy ], controller: "project_knowledge_activities"
      resources :project_directory_items, only: %i[ index show create update destroy ]
      resources :directory_items, only: %i[ index show create update destroy ], controller: "project_directory_items"
      resources :project_obsidian_notes, only: %i[ index show create update destroy ]
      resources :obsidian_notes, only: %i[ index show create update destroy ], controller: "project_obsidian_notes"
      resources :project_bottlenecks, only: %i[ index show create update destroy ]
      resources :bottlenecks, only: %i[ index show create update destroy ], controller: "project_bottlenecks"
      resources :project_todos, only: %i[ index show create update destroy ]
      resources :todos, only: %i[ index show create update destroy ], controller: "project_todos"
      resources :project_milestones, only: %i[ index show create update destroy ]
      resources :milestones, only: %i[ index show create update destroy ], controller: "project_milestones"
    end
  end

  # MCP Agent Chat API (Streamable HTTP transport)
  namespace :mcp do
    post "/", to: "endpoint#handle"
    get "/", to: "endpoint#handle_get"
    delete "/", to: "endpoint#handle_delete"
    get "/health", to: "endpoint#health"
    get "/setup", to: "setup#index"
    get "/setup/instructions", to: "setup#instructions"
  end

  # OAuth discovery endpoints - signal no auth required for MCP
  scope "/.well-known" do
    get "oauth-protected-resource", to: "well_known#oauth_protected_resource"
    get "oauth-protected-resource/*path", to: "well_known#oauth_protected_resource"
    get "oauth-authorization-server", to: "well_known#not_implemented"
    get "oauth-authorization-server/*path", to: "well_known#not_implemented"
    get "openid-configuration", to: "well_known#not_implemented"
    get "openid-configuration/*path", to: "well_known#not_implemented"
  end
  post "/register", to: "well_known#not_implemented"

  get "up" => "rails/health#show", as: :rails_health_check
end
