Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "auth/me", to: "auth/me#show"
      post "auth/login", to: "auth/sessions#create"
      post "auth/register", to: "auth/registrations#create"
      post "auth/recover-password", to: "auth/passwords#recover"
      post "auth/change-password", to: "auth/passwords#change"
      resources :users
      resources :roles
      resources :companies
      resources :skills
      resources :reference_links, path: "reference-links"
      resources :certifications
      resources :educations
      resources :opportunity_statuses, path: "opportunity-statuses"
      get "dashboard", to: "dashboard#show"
      resources :opportunities
      resources :resumes do
        patch "work-experiences", to: "resume_work_experiences#update"
        patch "certifications", to: "resume_certifications#update"
        patch "educations", to: "resume_educations#update"
        patch "skills", to: "resume_skills#update"
      end
      resources :work_experiences, path: "work-experiences" do
        patch "skills", to: "work_experience_skills#update"
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
end
