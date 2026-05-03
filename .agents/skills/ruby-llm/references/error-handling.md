<overview>
RubyLLM provides a hierarchy of exception classes for precise error handling. Automatic retries handle transient failures.
</overview>

<error_hierarchy>
## Error Hierarchy

```
RubyLLM::Error (base class)
├── ConfigurationError      # Missing API key or config
├── BadRequestError         # Invalid request parameters
├── UnauthorizedError       # Invalid API key
├── ForbiddenError          # Access denied
├── PaymentRequiredError    # Billing issue
├── RateLimitError          # Too many requests
├── ModelNotFoundError      # Invalid model name
├── ServiceUnavailableError # Provider down
└── TimeoutError            # Request timeout
```
</error_hierarchy>

<basic_handling>
## Basic Error Handling

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask("Hello")
rescue RubyLLM::Error => e
  puts "API error: #{e.message}"
rescue RubyLLM::ConfigurationError => e
  puts "Config missing: #{e.message}"
end
```
</basic_handling>

<specific_errors>
## Handling Specific Errors

```ruby
begin
  response = chat.ask("Generate a report")
rescue RubyLLM::UnauthorizedError
  puts "Check your API key configuration"
  # Maybe redirect to settings

rescue RubyLLM::PaymentRequiredError
  puts "Check your provider account balance"
  # Notify admin

rescue RubyLLM::RateLimitError
  puts "Rate limited - retry in 60 seconds"
  # Implement backoff

rescue RubyLLM::ModelNotFoundError => e
  puts "Model not found: #{e.message}"
  puts "Available: #{RubyLLM.models.chat_models.map(&:id)}"

rescue RubyLLM::ServiceUnavailableError
  puts "Provider temporarily unavailable"
  # Maybe try fallback provider

rescue RubyLLM::BadRequestError => e
  puts "Invalid request: #{e.message}"
  # Check the data being sent

rescue RubyLLM::Error => e
  puts "Unexpected error: #{e.message}"
end
```
</specific_errors>

<retry_config>
## Automatic Retries

Configure retry behavior:

```ruby
RubyLLM.configure do |config|
  config.max_retries = 5              # Default: 3
  config.retry_interval = 0.5         # Default: 0.1 seconds
  config.retry_backoff_factor = 2     # Exponential backoff
  config.retry_interval_randomness = 0.5  # Jitter
end
```

RubyLLM automatically retries on:
- Rate limit errors
- Service unavailable
- Temporary network issues
</retry_config>

<streaming_errors>
## Streaming Error Handling

Preserve partial content:

```ruby
begin
  accumulated = ""

  chat.ask("Generate long content...") do |chunk|
    print chunk.content
    accumulated << chunk.content.to_s
  end
rescue RubyLLM::RateLimitError
  puts "\nRate limited. Got: #{accumulated}"
rescue RubyLLM::Error => e
  puts "\nFailed: #{e.message}"
  puts "Partial content: #{accumulated}"
end
```
</streaming_errors>

<raw_response>
## Accessing Raw Response

For debugging:

```ruby
begin
  response = chat.ask("Test")

  # Inspect response details
  puts response.raw.status
  puts response.raw.headers
  puts response.raw.body
rescue RubyLLM::Error => e
  # Inspect error response
  puts "Status: #{e.response&.status}"
  puts "Body: #{e.response&.body}"
end
```
</raw_response>

<tool_errors>
## Tool Error Handling

In tools, return errors instead of raising:

```ruby
class MyTool < RubyLLM::Tool
  def execute(query:)
    return { error: "Query too short" } if query.length < 3

    result = ExternalAPI.call(query)
    { data: result }

  rescue Faraday::ConnectionFailed
    { error: "Service unavailable" }  # Recoverable

  rescue ActiveRecord::RecordNotFound => e
    raise e  # Unrecoverable - let it propagate
  end
end
```
</tool_errors>

<production_pattern>
## Production Pattern

```ruby
class AiService
  def ask(prompt)
    chat.ask(prompt)
  rescue RubyLLM::RateLimitError
    # Retry with backoff
    sleep(60)
    retry
  rescue RubyLLM::Error => e
    Sentry.capture_exception(e, extra: {
      model: chat.model,
      prompt_preview: prompt.first(100)
    }) if defined?(Sentry)

    { error: "AI service temporarily unavailable" }
  end

  private

  def chat
    @chat ||= RubyLLM.chat(model: 'gpt-4.1')
  end
end
```
</production_pattern>

<logging>
## Logging

Enable for debugging:

```ruby
RubyLLM.configure do |config|
  config.logger = Rails.logger
  config.log_level = :debug  # Verbose
  # Or to file:
  config.log_file = Rails.root.join('log/ruby_llm.log')
end
```
</logging>

<timeout>
## Timeout Configuration

```ruby
RubyLLM.configure do |config|
  config.request_timeout = 120  # 2 minutes
end

# Per-request timeout
begin
  response = chat.ask("Long task...")
rescue RubyLLM::TimeoutError
  puts "Request timed out"
end
```
</timeout>
