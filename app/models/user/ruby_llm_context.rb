# frozen_string_literal: true

# Per-request OpenAI credentials for RubyLLM: prefers the user's `ai_token`, then `OPENAI_API_KEY`.
class User::RubyLlmContext
  class MissingApiKeyError < StandardError; end

  class << self
    def openai_api_key_for(user)
      user&.ai_token.to_s.strip.presence ||
        ENV.fetch("OPENAI_API_KEY", "").to_s.strip.presence
    end

    def openai_chat!(user:, model:)
      key = openai_api_key_for(user)
      raise MissingApiKeyError if key.blank?

      RubyLLM.context do |c|
        c.openai_api_key = key
      end.chat(model: model)
    end
  end
end
