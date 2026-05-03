# frozen_string_literal: true

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.request_timeout = ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT", 120).to_i
  config.max_retries = ENV.fetch("RUBY_LLM_MAX_RETRIES", 3).to_i
end
