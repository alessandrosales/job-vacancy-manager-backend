# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/resumes/description-suggestions" do
  let(:user) do
    User.create!(
      name: "Desc Ai User",
      email: "desc-ai@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:auth_headers) { { "Authorization" => "Bearer #{User::JwtIssuer.encode(user)}" } }

  before do
    response_obj = Struct.new(:content).new("  Polished summary for the candidate.  ")
    chat_double = Object.new
    chat_double.define_singleton_method(:ask) { |_msg| response_obj }
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_return(chat_double)
  end

  it "returns 200 and description when title is present" do
    post "/api/v1/resumes/description-suggestions",
      params: {
        title: "Senior Engineer",
        role_name: "Backend",
        preferred_language: "pt_br",
        work_experience_summaries: [ "Acme — Lead" ],
        certification_names: [ "AWS" ],
        education_summaries: [ "State U — BSc" ],
        skill_names: [ "Ruby", "Rails" ],
        previous_description: "Draft notes"
      },
      headers: auth_headers.merge("Content-Type" => "application/json"),
      as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["description"]).to eq("Polished summary for the candidate.")
  end

  it "returns 422 when title is blank" do
    post "/api/v1/resumes/description-suggestions",
      params: { title: "   ", role_name: "X" },
      headers: auth_headers.merge("Content-Type" => "application/json"),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to have_key("title")
  end

  it "returns 422 when no OpenAI API key is available" do
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_call_original
    allow(User::RubyLlmContext).to receive(:openai_api_key_for).and_return(nil)

    post "/api/v1/resumes/description-suggestions",
      params: { title: "T" },
      headers: auth_headers.merge("Content-Type" => "application/json"),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]["ai_token"]).to be_present
  end

  it "returns 422 when RubyLLM fails" do
    allow(User::RubyLlmContext).to receive(:openai_chat!).and_raise(RubyLLM::Error.new("upstream"))

    post "/api/v1/resumes/description-suggestions",
      params: { title: "T" },
      headers: auth_headers.merge("Content-Type" => "application/json"),
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]["base"]).to be_present
  end
end
