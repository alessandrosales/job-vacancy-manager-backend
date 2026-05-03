# Workflow: Debug LLM Interactions

<required_reading>
**Read these reference files NOW:**
1. references/error-handling.md
2. references/providers.md
3. references/chat-api.md
</required_reading>

<process>
## Step 1: Identify the Error Type

Check which error you're seeing:

| Error | Cause | Fix |
|-------|-------|-----|
| `ConfigurationError` | Missing API key | Set ENV variable |
| `UnauthorizedError` | Invalid API key | Check key is correct |
| `RateLimitError` | Too many requests | Wait and retry |
| `PaymentRequiredError` | Account issue | Check provider billing |
| `ModelNotFoundError` | Invalid model name | Use `RubyLLM.models.all` |
| `BadRequestError` | Invalid request | Check parameters |
| `ServiceUnavailableError` | Provider down | Retry later |

## Step 2: Enable Logging

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']

  # Enable logging
  config.logger = Rails.logger
  config.log_level = :debug

  # Or log to file
  config.log_file = Rails.root.join('log/ruby_llm.log')
end
```

## Step 3: Inspect Raw Response

Access the underlying Faraday response:

```ruby
begin
  response = chat.ask("Test prompt")

  # Inspect raw response
  puts response.raw.status        # => 200
  puts response.raw.headers       # => {...}
  puts response.raw.body          # => {...}
  puts response.raw.env.request_body  # What was sent
rescue RubyLLM::Error => e
  puts "Error: #{e.message}"
  puts "Status: #{e.response&.status}"
  puts "Body: #{e.response&.body}"
end
```

## Step 4: Common Issues and Fixes

**Issue: "API key not found"**
```ruby
# Check key is set
puts ENV['OPENAI_API_KEY'].present?  # Should be true
puts ENV['OPENAI_API_KEY'][0..10]    # First chars to verify
```

**Issue: Model not working**
```ruby
# List available models
RubyLLM.models.chat_models.map(&:id)
RubyLLM.models.by_provider(:openai).map(&:id)

# Check model capabilities
model = RubyLLM.models.find('gpt-4.1')
puts model.supports_vision?
puts model.supports_functions?
```

**Issue: Tool not being called**
```ruby
# Check tool is attached
puts chat.tools.map(&:name)

# Check tool description is clear
# Bad: "Does stuff"
# Good: "Search products by name, category, or price range"
```

**Issue: Streaming not working**
```ruby
# Test basic streaming
chat.ask("Say hello") do |chunk|
  puts "Got chunk: #{chunk.content.inspect}"
end

# Check if model supports streaming
model = RubyLLM.models.find(chat.model)
puts model.supports_streaming?
```

**Issue: Rate limiting**
```ruby
# Configure retries
RubyLLM.configure do |config|
  config.max_retries = 5
  config.retry_interval = 1.0  # Wait 1 second between retries
end
```

**Issue: Timeout**
```ruby
RubyLLM.configure do |config|
  config.request_timeout = 300  # 5 minutes for long operations
end
```

## Step 5: Test in Isolation

Create a minimal test case:

```ruby
# In console
require 'ruby_llm'

RubyLLM.configure do |c|
  c.openai_api_key = ENV['OPENAI_API_KEY']
end

# Minimal test
chat = RubyLLM.chat(model: 'gpt-4.1-mini')
response = chat.ask("Say 'test' and nothing else")
puts response.content
```

## Step 6: Check Provider Status

- OpenAI: https://status.openai.com
- Anthropic: https://status.anthropic.com
- Google: https://status.cloud.google.com

## Step 7: Structured Error Handling

```ruby
def safe_ask(chat, prompt)
  chat.ask(prompt)
rescue RubyLLM::UnauthorizedError
  { error: "Check API key configuration" }
rescue RubyLLM::RateLimitError
  { error: "Rate limited, retry in 60 seconds" }
rescue RubyLLM::ModelNotFoundError => e
  { error: "Model not found: #{e.message}" }
rescue RubyLLM::BadRequestError => e
  { error: "Bad request: #{e.message}" }
rescue RubyLLM::Error => e
  Sentry.capture_exception(e) if defined?(Sentry)
  { error: "Unexpected error: #{e.message}" }
end
```
</process>

<anti_patterns>
Avoid:
- Catching and ignoring errors silently
- Not logging errors to Sentry/error tracker
- Hardcoding API keys for debugging
- Testing in production instead of console
</anti_patterns>

<success_criteria>
Debugging is complete when:
- [ ] Error type identified
- [ ] Root cause found
- [ ] Fix verified in console
- [ ] Error handling added to prevent recurrence
- [ ] Logged to error tracker if needed
</success_criteria>
