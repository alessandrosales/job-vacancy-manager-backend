Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth/sessions#create"
      resources :users
      resources :roles
      resources :skills
      resources :reference_links
      resources :certifications
      resources :educations
      resources :opportunity_statuses
      resources :opportunities
      resources :resumes do
        patch "work_experiences", to: "resume_work_experiences#update"
        patch "certifications", to: "resume_certifications#update"
        patch "educations", to: "resume_educations#update"
        patch "skills", to: "resume_skills#update"
      end
      resources :work_experiences do
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
