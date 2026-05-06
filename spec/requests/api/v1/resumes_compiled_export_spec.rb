# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/resumes/:resume_id/compiled-export" do
  let(:user) do
    User.create!(
      name: "Export User",
      email: "export-user@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:role) { user.roles.create!(name: "Dev", interest_level: 3) }
  let(:auth_headers) { { "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}" } }

  let(:markdown_source) do
    <<~MD
      # Jane Doe

      **Bold** intro and _italic_ note.

      ---

      - First bullet
      - Second bullet
    MD
  end

  let!(:resume) do
    user.resumes.create!(
      title: "CV / 2026",
      role: role,
      compiled_markdown: markdown_source
    )
  end

  it "returns markdown attachment when format=md" do
    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "md" },
      headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.headers["Content-Disposition"]).to include("cv-2026.md")
    expect(response.body).to eq(markdown_source)
  end

  it "returns PDF bytes when format=pdf" do
    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "pdf" },
      headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include(".pdf")
    expect(response.body.bytesize).to be > 100
    expect(response.body).to start_with("%PDF")
  end

  it "returns DOCX bytes when format=docx" do
    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "docx" },
      headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    expect(response.headers["Content-Disposition"]).to include(".docx")
    expect(response.body.bytesize).to be > 500
    expect(response.body).to start_with("PK")
  end

  it "returns 422 when compiled_markdown is blank" do
    resume.update_column(:compiled_markdown, nil)

    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "md" },
      headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    json = JSON.parse(response.body)
    expect(json["errors"]["base"]).to include(/not available/)
  end

  it "returns 422 for invalid format" do
    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "rtf" },
      headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    json = JSON.parse(response.body)
    expect(json["errors"]["base"]).to include(/invalid/i)
  end

  it "returns 404 when resume belongs to another user" do
    other = User.create!(
      name: "Other",
      email: "other-export@example.com",
      password: "password12",
      password_confirmation: "password12"
    )

    get "/api/v1/resumes/#{resume.id}/compiled-export",
      params: { format: "md" },
      headers: { "Authorization" => "Bearer #{User::JwtIssuer.encode(other)}" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns 401 without auth" do
    get "/api/v1/resumes/#{resume.id}/compiled-export", params: { format: "md" }

    expect(response).to have_http_status(:unauthorized)
  end
end
