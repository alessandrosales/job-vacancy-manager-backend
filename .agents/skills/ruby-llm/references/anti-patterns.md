<overview>
Common mistakes when using RubyLLM and how to avoid them.
</overview>

<api_keys>
## API Key Anti-Patterns

```ruby
# Bad: Hardcoded API key
RubyLLM.configure do |config|
  config.openai_api_key = "sk-abc123..."  # NEVER do this
end

# Good: Environment variable
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```
</api_keys>

<sync_controller>
## Synchronous Controller Calls

```ruby
# Bad: Blocks the request
class ChatsController < ApplicationController
  def create
    @chat = Chat.create!(model: 'gpt-4.1')
    response = @chat.ask(params[:message])  # 5-30 seconds!
    render json: response.content
  end
end

# Good: Background job
class ChatsController < ApplicationController
  def create
    @chat = Chat.create!(model: 'gpt-4.1')
    @chat.messages.create!(role: 'user', content: params[:message])
    ChatProcessJob.perform_later(@chat.id)
    head :accepted
  end
end
```
</sync_controller>

<error_swallowing>
## Swallowing Errors

```ruby
# Bad: Silent failure
def summarize
  chat.ask(prompt)
rescue
  nil  # What went wrong?
end

# Good: Log and handle
def summarize
  chat.ask(prompt)
rescue RubyLLM::Error => e
  Sentry.capture_exception(e) if defined?(Sentry)
  { error: e.message }
end
```
</error_swallowing>

<tool_exceptions>
## Raising in Tools

```ruby
# Bad: Exceptions halt the conversation
class WeatherTool < RubyLLM::Tool
  def execute(location:)
    raise "Location not found" if location.blank?
    fetch_weather(location)
  end
end

# Good: Return error objects
class WeatherTool < RubyLLM::Tool
  def execute(location:)
    return { error: "Location required" } if location.blank?

    begin
      fetch_weather(location)
    rescue Faraday::Error => e
      { error: "Weather service unavailable" }
    end
  end
end
```
</tool_exceptions>

<vague_descriptions>
## Vague Tool Descriptions

```ruby
# Bad: LLM doesn't know when to use it
class MyTool < RubyLLM::Tool
  description "Does stuff with data"
end

# Good: Clear purpose
class ProductSearchTool < RubyLLM::Tool
  description "Search products by name, category, or price range. Returns matching products with id, name, and price."
end
```
</vague_descriptions>

<unstructured_returns>
## Unstructured Tool Returns

```ruby
# Bad: String return
def execute(query:)
  "Found 5 products matching '#{query}'"
end

# Good: Structured data
def execute(query:)
  products = Product.search(query)
  {
    count: products.count,
    products: products.map { |p| { id: p.id, name: p.name, price: p.price } }
  }
end
```
</unstructured_returns>

<message_validation>
## Validating Message Content

```ruby
# Bad: Breaks streaming
class Message < ApplicationRecord
  acts_as_message
  validates :content, presence: true  # Assistant messages start empty!
end

# Good: Only validate role
class Message < ApplicationRecord
  acts_as_message
  validates :role, presence: true
  validates :chat, presence: true
end
```
</message_validation>

<no_timeout>
## Missing Timeout Configuration

```ruby
# Bad: Default timeout may be too short
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end

# Good: Configure for your use case
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.request_timeout = 120  # 2 minutes for long operations
end
```
</no_timeout>

<wrong_model>
## Wrong Model for Task

```ruby
# Bad: Expensive model for simple task
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.ask("Say hello")  # Overkill!

# Good: Match model to task
def select_model(complexity)
  case complexity
  when :simple then 'gpt-4.1-mini'
  when :complex then 'gpt-4.1'
  end
end
```
</wrong_model>

<no_caching>
## No Embedding Caching

```ruby
# Bad: Recompute every time
def similar_documents(query)
  query_embedding = RubyLLM.embed(query).vectors.first  # Called repeatedly
  Document.similar_to(query_embedding)
end

# Good: Cache embeddings
def embedding_for(text)
  Rails.cache.fetch("embedding:#{Digest::SHA256.hexdigest(text)}", expires_in: 1.week) do
    RubyLLM.embed(text).vectors.first
  end
end
```
</no_caching>

<no_retries>
## No Retry Logic

```ruby
# Bad: Fails on first error
response = chat.ask(prompt)

# Good: Configure retries
RubyLLM.configure do |config|
  config.max_retries = 5
  config.retry_interval = 0.5
  config.retry_backoff_factor = 2
end
```
</no_retries>

<streaming_controller>
## Streaming in Controller

```ruby
# Bad: Blocks the connection
def create
  chat.ask(params[:message]) do |chunk|
    response.stream.write(chunk.content)  # Ties up connection
  end
end

# Good: Background job with Turbo Streams
def create
  @chat.messages.create!(role: 'user', content: params[:message])
  ChatStreamJob.perform_later(@chat.id)
  head :ok
end
```
</streaming_controller>

<ignoring_tokens>
## Ignoring Token Usage

```ruby
# Bad: No monitoring
chat.ask("Process this large document...")

# Good: Track usage
response = chat.ask("Process this...")
Metrics.increment('llm.tokens', response.input_tokens + response.output_tokens)
Metrics.increment('llm.requests')
```
</ignoring_tokens>

<summary>
## Summary

| Anti-Pattern | Fix |
|--------------|-----|
| Hardcoded API keys | Use ENV variables |
| Sync controller calls | Use background jobs |
| Swallowing errors | Log to Sentry |
| Raising in tools | Return `{ error: ... }` |
| Vague tool descriptions | Be specific about purpose |
| Validating message content | Only validate role |
| No timeout | Configure request_timeout |
| No caching | Cache embeddings |
| No retries | Configure max_retries |
| No monitoring | Track tokens and requests |
</summary>
