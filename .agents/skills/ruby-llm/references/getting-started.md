<overview>
Installation, configuration, and basic usage of RubyLLM. This is the starting point for all RubyLLM projects.
</overview>

<installation>
## Installation

Add to Gemfile:

```ruby
gem 'ruby_llm'

# Optional: for structured output schemas
gem 'ruby_llm-schema'

# Optional: for MCP integration
gem 'ruby_llm-mcp'
```

Run:
```bash
bundle install
```

RubyLLM has only 3 dependencies: Faraday, Zeitwerk, and Marcel.
</installation>

<configuration>
## Configuration

Create initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  # Provider API Keys (only set what you use)
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.mistral_api_key = ENV['MISTRAL_API_KEY']

  # Local providers
  config.ollama_api_base = 'http://localhost:11434/v1'

  # AWS Bedrock
  config.bedrock_region = ENV['AWS_REGION']
  # Uses standard AWS credential chain if keys not set

  # Defaults
  config.default_model = 'gpt-4.1'
  config.default_embedding_model = 'text-embedding-3-small'

  # Connection settings
  config.request_timeout = 120
  config.max_retries = 3
  config.retry_interval = 0.5
end
```
</configuration>

<basic_usage>
## Basic Usage

**Simple chat:**
```ruby
chat = RubyLLM.chat
response = chat.ask("What is Ruby?")
puts response.content
```

**Choose a model:**
```ruby
chat = RubyLLM.chat(model: 'claude-sonnet-4-5')
chat = RubyLLM.chat(model: 'gpt-4.1')
chat = RubyLLM.chat(model: 'gemini-2.0-flash')
```

**Multi-turn conversation:**
```ruby
chat = RubyLLM.chat
chat.ask("My name is Alice")
chat.ask("What's my name?")  # "Your name is Alice"
```

**With files:**
```ruby
chat.ask("What's in this image?", with: "photo.jpg")
chat.ask("Summarize this", with: "report.pdf")
chat.ask("Transcribe this", with: "meeting.mp3")
```

**System prompt:**
```ruby
chat.with_system("You are a helpful coding assistant. Be concise.")
chat.ask("How do I read a file in Ruby?")
```
</basic_usage>

<other_capabilities>
## Other Capabilities

**Embeddings:**
```ruby
embedding = RubyLLM.embed("Ruby is elegant")
puts embedding.vectors.first.length  # => 1536

# Batch embeddings
embeddings = RubyLLM.embed(["Ruby", "Python", "JavaScript"])
```

**Image generation:**
```ruby
image = RubyLLM.paint("A sunset over mountains")
image.save("sunset.png")

# Or get URL/base64
puts image.url if image.url
puts image.data if image.base64?
```

**Audio transcription:**
```ruby
transcription = RubyLLM.transcribe("meeting.wav")
puts transcription.text
```

**Content moderation:**
```ruby
result = RubyLLM.moderate("Some text to check")
puts result.flagged?
```
</other_capabilities>

<model_registry>
## Model Registry

List available models:

```ruby
# All models
RubyLLM.models.all

# By capability
RubyLLM.models.chat_models
RubyLLM.models.embedding_models
RubyLLM.models.image_models

# By provider
RubyLLM.models.by_provider(:openai)
RubyLLM.models.by_provider(:anthropic)

# Find specific model
model = RubyLLM.models.find('gpt-4.1')
puts model.supports_vision?
puts model.supports_functions?
puts model.context_window
```
</model_registry>

<verification>
## Verify Setup

```bash
bin/rails console
> RubyLLM.chat.ask("Say 'hello' and nothing else")
=> #<RubyLLM::Message content="hello">
```

If you get errors:
- `ConfigurationError`: Check ENV variable is set
- `UnauthorizedError`: Check API key is valid
- `ModelNotFoundError`: Check model name with `RubyLLM.models.all`
</verification>
