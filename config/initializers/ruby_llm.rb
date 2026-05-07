# frozen_string_literal: true

RubyLLM.configure do |config|
  # Default for code paths that do not use `User::RubyLlmContext`. AI features use the signed-in
  # user's `ai_token` when present; see `User::RubyLlmContext.openai_api_key_for`.
  config.openai_api_key = ENV["OPENAI_API_KEY"].to_s.presence
  config.request_timeout = ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT", 120).to_i
  config.max_retries = ENV.fetch("RUBY_LLM_MAX_RETRIES", 3).to_i
end
