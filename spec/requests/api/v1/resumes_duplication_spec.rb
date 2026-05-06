# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/resumes/:resume_id/duplication" do
  let(:user) do
    User.create!(
      name: "Dup User",
      email: "resume-dup@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:role) { user.roles.create!(name: "AI Engineer", interest_level: 4) }
  let(:auth_headers) { { "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}" } }

  let!(:work_experience) { user.work_experiences.create!(title: "Senior", company_name: "Acme", is_remote: true) }
  let!(:certification) { user.certifications.create!(name: "Ruby Cert") }
  let!(:education) { user.educations.create!(institution_name: "UFX", field_of_study: "Computer Science") }
  let!(:skill) { user.skills.create!(name: "Ruby", description: "Rails") }

  let!(:resume) do
    user.resumes.create!(
      title: "Senior AI Engineer",
      role: role,
      description: "Original description",
      preferred_language: "pt_br",
      compiled_markdown: "# Senior AI Engineer"
    )
  end

  before do
    resume.sync_work_experience_links!(user, [ work_experience.id ])
    resume.sync_certification_links!(user, [ certification.id ])
    resume.sync_education_links!(user, [ education.id ])
    resume.sync_skill_links!(user, [ skill.id ])
  end

  it "duplicates the resume with join links and returns created payload" do
    expect do
      post "/api/v1/resumes/#{resume.id}/duplication", headers: auth_headers
    end.to change(Resume, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    duplicated = user.resumes.find(body.fetch("id"))

    expect(body["title"]).to eq("Senior AI Engineer (Copy)")
    expect(body["description"]).to eq("Original description")
    expect(body["preferred_language"]).to eq("pt_br")
    expect(body["compiled_markdown"]).to eq("# Senior AI Engineer")
    expect(body["role_id"]).to eq(role.id)
    expect(body["work_experience_ids"]).to eq([ work_experience.id ])
    expect(body["certification_ids"]).to eq([ certification.id ])
    expect(body["education_ids"]).to eq([ education.id ])
    expect(body["skill_ids"]).to eq([ skill.id ])

    expect(duplicated).to be_present
    expect(duplicated.id).not_to eq(resume.id)
  end

  it "returns 404 when resume belongs to another user" do
    other = User.create!(
      name: "Other Dup",
      email: "other-dup@example.com",
      password: "password12",
      password_confirmation: "password12"
    )

    post "/api/v1/resumes/#{resume.id}/duplication",
      headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(other)}" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns 401 without auth" do
    post "/api/v1/resumes/#{resume.id}/duplication"

    expect(response).to have_http_status(:unauthorized)
  end
end
