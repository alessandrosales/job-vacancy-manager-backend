# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/resumes/pdf-import" do
  let(:user) do
    User.create!(
      name: "Pdf Api User",
      email: "pdf-api@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:role) { user.roles.create!(name: "Dev", interest_level: 2) }
  let(:auth_headers) { { "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}" } }

  let(:payload) do
    {
      "resume" => { "title" => "From API" },
      "work_experiences" => [],
      "educations" => [],
      "certifications" => [],
      "skills" => []
    }
  end

  before do
    response_double = double(content: payload)
    chat_double = Object.new
    chat_double.define_singleton_method(:with_schema) { |_schema| self }
    chat_double.define_singleton_method(:ask) { |_prompt, with: nil| response_double }
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_return(chat_double)
  end

  it "returns 201 and resume JSON when file and role_id are valid" do
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 minimal\n"), "application/pdf", original_filename: "cv.pdf")

    post "/api/v1/resumes/pdf-import", params: { file: pdf, role_id: role.id }, headers: auth_headers

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["title"]).to eq("From API")
    expect(body["user_id"]).to eq(user.id)
    expect(body["role_id"]).to eq(role.id)
    expect(body["preferred_language"]).to eq("en")
  end

  it "returns 201 with preferred_language from multipart param" do
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 minimal\n"), "application/pdf", original_filename: "cv.pdf")

    post "/api/v1/resumes/pdf-import",
      params: { file: pdf, role_id: role.id, preferred_language: "es" },
      headers: auth_headers

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)["preferred_language"]).to eq("es")
  end

  it "returns 422 when file is missing" do
    post "/api/v1/resumes/pdf-import", params: { role_id: role.id }, headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to have_key("file")
  end

  it "returns 404 when role_id is not for the current user" do
    other = User.create!(
      name: "O",
      email: "pdf-api-other@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    foreign_role = other.roles.create!(name: "R", interest_level: 1)
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n"), "application/pdf", original_filename: "cv.pdf")

    post "/api/v1/resumes/pdf-import", params: { file: pdf, role_id: foreign_role.id }, headers: auth_headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns 422 when no OpenAI API key is available" do
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_call_original
    allow(User::RubyLlmContext).to receive(:openai_api_key_for).and_return(nil)
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n"), "application/pdf", original_filename: "cv.pdf")

    post "/api/v1/resumes/pdf-import", params: { file: pdf, role_id: role.id }, headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]["ai_token"]).to be_present
  end

  it "returns 422 when RubyLLM fails" do
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_raise(RubyLLM::Error.new("upstream"))
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n"), "application/pdf", original_filename: "cv.pdf")

    post "/api/v1/resumes/pdf-import", params: { file: pdf, role_id: role.id }, headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]["base"]).to be_present
  end
end
