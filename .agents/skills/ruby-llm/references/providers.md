<overview>
RubyLLM supports 600+ models from major providers with a unified API. Configure only the providers you use.
</overview>

<supported_providers>
## Supported Providers

| Provider | Models | Notes |
|----------|--------|-------|
| OpenAI | GPT-4, GPT-4.1, DALL-E, Whisper | Most mature support |
| Anthropic | Claude 3.5, Claude 3 | 200k context window |
| Google | Gemini 2.0, Gemini 1.5, Imagen | Good multimodal |
| AWS Bedrock | Various hosted models | Enterprise-ready |
| DeepSeek | DeepSeek models | Cost-effective |
| Mistral | Mistral models | Open weights |
| Ollama | Local models | Privacy-focused |
| OpenRouter | 100+ models | Model aggregator |
| Perplexity | Search-augmented | Built-in search |
</supported_providers>

<configuration>
## Configuration

```ruby
RubyLLM.configure do |config|
  # OpenAI
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_organization_id = ENV['OPENAI_ORG_ID']  # Optional

  # Anthropic
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Google
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  # OR for VertexAI:
  config.vertexai_project_id = ENV['GOOGLE_CLOUD_PROJECT']
  config.vertexai_location = ENV['GOOGLE_CLOUD_LOCATION']

  # AWS Bedrock
  config.bedrock_region = ENV['AWS_REGION']
  # Uses standard AWS credential chain if keys not set

  # Local (Ollama)
  config.ollama_api_base = 'http://localhost:11434/v1'

  # Others
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.mistral_api_key = ENV['MISTRAL_API_KEY']
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.perplexity_api_key = ENV['PERPLEXITY_API_KEY']
end
```
</configuration>

<model_selection>
## Model Selection

```ruby
# By provider
chat = RubyLLM.chat(model: 'gpt-4.1')           # OpenAI
chat = RubyLLM.chat(model: 'claude-sonnet-4-5') # Anthropic
chat = RubyLLM.chat(model: 'gemini-2.0-flash')  # Google

# List available models
RubyLLM.models.by_provider(:openai).map(&:id)
RubyLLM.models.by_provider(:anthropic).map(&:id)

# Find model info
model = RubyLLM.models.find('gpt-4.1')
puts model.context_window
puts model.supports_vision?
puts model.supports_functions?
```
</model_selection>

<custom_endpoints>
## Custom OpenAI-Compatible Endpoints

For vLLM, LiteLLM, or other compatible servers:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = 'dummy-key'  # Or actual key if needed
  config.openai_api_base = 'http://localhost:8080/v1'
end

# Use custom model name
chat = RubyLLM.chat(
  model: 'my-local-model',
  provider: :openai,
  assume_model_exists: true
)
```
</custom_endpoints>

<multi_tenant>
## Multi-Tenant Configuration

Isolate configuration per tenant:

```ruby
class TenantService
  def initialize(tenant)
    @context = RubyLLM.context do |config|
      config.openai_api_key = tenant.openai_key
      config.anthropic_api_key = tenant.anthropic_key
      config.default_model = tenant.preferred_model
    end
  end

  def chat
    @context.chat
  end

  def embed(text)
    @context.embed(text)
  end
end

# Each tenant uses their own API keys
service = TenantService.new(current_tenant)
service.chat.ask("Hello")
```
</multi_tenant>

<model_comparison>
## Model Comparison

| Use Case | Recommended | Why |
|----------|-------------|-----|
| Fast, cheap tasks | `gpt-4.1-mini` | Low cost, fast |
| Complex reasoning | `gpt-4.1`, `claude-sonnet-4-5` | High quality |
| Very long context | `claude-sonnet-4-5` | 200k tokens |
| Vision tasks | `gpt-4.1`, `gemini-2.0-flash` | Strong multimodal |
| Code generation | `claude-sonnet-4-5`, `gpt-4.1` | Best for code |
| Local/private | `ollama:llama3` | No data leaves server |
| Cost optimization | DeepSeek, Mistral | Lower per-token cost |
</model_comparison>

<fallback_pattern>
## Fallback Pattern

```ruby
def ask_with_fallback(prompt)
  providers = ['gpt-4.1', 'claude-sonnet-4-5', 'gemini-2.0-flash']

  providers.each do |model|
    begin
      return RubyLLM.chat(model: model).ask(prompt)
    rescue RubyLLM::ServiceUnavailableError, RubyLLM::RateLimitError
      next
    end
  end

  raise "All providers failed"
end
```
</fallback_pattern>

<refresh_models>
## Refresh Model Registry

Get latest models from providers:

```ruby
# Fetch latest from all configured providers
RubyLLM::Model.refresh!

# Check specific model
model = RubyLLM.models.find('gpt-4.1-turbo-2024-04-09')
```
</refresh_models>
