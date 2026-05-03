# Workflow: Optimize for Production

<required_reading>
**Read these reference files NOW:**
1. references/error-handling.md
2. references/providers.md
3. references/rails-integration.md
</required_reading>

<process>
## Step 1: Configure for Production

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  # API keys from environment
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Robust retry settings
  config.max_retries = 5
  config.retry_interval = 0.5
  config.retry_backoff_factor = 2

  # Reasonable timeout
  config.request_timeout = 120

  # Production logging
  config.logger = Rails.logger
  config.log_level = :warn  # Only warnings and errors
end
```

## Step 2: Use Background Jobs

Never call LLMs synchronously in controllers:

```ruby
# Bad - blocks request
class ChatsController < ApplicationController
  def create
    @chat = Chat.create!(model: 'gpt-4.1')
    @chat.ask(params[:message])  # Blocks for seconds!
    redirect_to @chat
  end
end

# Good - async processing
class ChatsController < ApplicationController
  def create
    @chat = Chat.create!(model: 'gpt-4.1')
    @chat.messages.create!(role: 'user', content: params[:message])
    ChatProcessJob.perform_later(@chat.id)
    redirect_to @chat
  end
end
```

**Idempotent job:**

```ruby
class ChatProcessJob < ApplicationJob
  queue_as :default

  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5

  discard_on RubyLLM::UnauthorizedError do |job, error|
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def perform(chat_id)
    chat = Chat.find(chat_id)

    # Idempotency guard
    return if chat.messages.last.role == 'assistant' && chat.messages.last.content.present?

    chat.complete do |chunk|
      if chunk.content
        chat.messages.last.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
```

## Step 3: Choose the Right Model

Balance cost, speed, and quality:

| Use Case | Model | Why |
|----------|-------|-----|
| Simple tasks | `gpt-4.1-mini` | Fast, cheap |
| Complex reasoning | `gpt-4.1` | Better quality |
| Very long context | `claude-sonnet-4-5` | 200k context |
| Local/private | `ollama:llama3` | No data leaves server |

```ruby
# Route to appropriate model
def select_model(task_complexity)
  case task_complexity
  when :simple then 'gpt-4.1-mini'
  when :complex then 'gpt-4.1'
  when :very_long then 'claude-sonnet-4-5'
  end
end
```

## Step 4: Optimize Token Usage

```ruby
# Limit response length
chat.with_params(max_tokens: 500)

# Use system prompts for consistent behavior
chat.with_system("You are a helpful assistant. Be concise.")

# Truncate context for long conversations
def ask_with_context(chat, message)
  # Keep only last 10 messages for context
  recent = chat.messages.order(created_at: :desc).limit(10).reverse

  # Create new chat with context summary
  summarized = RubyLLM.chat(model: 'gpt-4.1-mini')
  summarized.ask("Summarize this conversation: #{recent.map(&:content).join("\n")}")

  chat.with_context(summarized.content).ask(message)
end
```

## Step 5: Implement Caching

```ruby
# Cache embeddings
class Document < ApplicationRecord
  def embedding
    Rails.cache.fetch("doc:#{id}:embedding", expires_in: 1.week) do
      RubyLLM.embed(content).vectors.first
    end
  end
end

# Cache common responses
def cached_response(prompt_key, prompt)
  Rails.cache.fetch("llm:#{prompt_key}", expires_in: 1.hour) do
    RubyLLM.chat.ask(prompt).content
  end
end
```

## Step 6: Async Concurrency

For batch operations, use Ruby's async:

```ruby
require 'async'

def batch_embed(texts)
  Async do
    texts.map do |text|
      Async do
        RubyLLM.embed(text)
      end
    end.map(&:wait)
  end.wait
end

# Process 100 texts concurrently
embeddings = batch_embed(texts)
```

## Step 7: Multi-Tenant Configuration

Isolate configuration per tenant:

```ruby
class TenantService
  def initialize(tenant)
    @context = RubyLLM.context do |config|
      config.openai_api_key = tenant.openai_key
      config.default_model = tenant.preferred_model
      config.request_timeout = tenant.timeout_seconds
    end
  end

  def chat
    @context.chat
  end
end

# Each tenant gets isolated configuration
tenant_service = TenantService.new(current_tenant)
tenant_service.chat.ask("Hello")
```

## Step 8: Monitoring

```ruby
# Track usage in callbacks
chat.on_end_message do |message|
  if message
    Metrics.increment('llm.requests')
    Metrics.histogram('llm.tokens', message.input_tokens + message.output_tokens)
    Metrics.timing('llm.duration', message.duration_ms)
  end
end

# Error tracking
rescue RubyLLM::Error => e
  Sentry.capture_exception(e, extra: {
    model: chat.model,
    provider: chat.provider
  }) if defined?(Sentry)
end
```
</process>

<anti_patterns>
Avoid:
- Synchronous LLM calls in web requests
- Using expensive models for simple tasks
- Not implementing retries
- Ignoring token costs
- Missing error tracking
</anti_patterns>

<success_criteria>
Production-ready when:
- [ ] All LLM calls in background jobs
- [ ] Appropriate model selection
- [ ] Retry logic configured
- [ ] Error tracking enabled
- [ ] Token usage monitored
- [ ] Caching where appropriate
</success_criteria>
