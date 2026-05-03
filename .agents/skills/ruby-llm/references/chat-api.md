<overview>
The Chat API is the core interface for conversational AI in RubyLLM. It provides a unified interface across all providers with automatic context management.
</overview>

<creating_chats>
## Creating Chats

```ruby
# Default model
chat = RubyLLM.chat

# Specific model
chat = RubyLLM.chat(model: 'gpt-4.1')
chat = RubyLLM.chat(model: 'claude-sonnet-4-5')
chat = RubyLLM.chat(model: 'gemini-2.0-flash')

# With provider hint (for custom endpoints)
chat = RubyLLM.chat(model: 'my-model', provider: :openai, assume_model_exists: true)
```
</creating_chats>

<asking_questions>
## Asking Questions

```ruby
# Simple ask
response = chat.ask("What is Ruby?")
puts response.content

# With files (multimodal)
response = chat.ask("Describe this image", with: "photo.jpg")
response = chat.ask("Summarize this PDF", with: "report.pdf")
response = chat.ask("What's in these?", with: ["image1.jpg", "image2.jpg"])

# Streaming (see streaming reference)
chat.ask("Tell me a story") do |chunk|
  print chunk.content
end
```
</asking_questions>

<response_object>
## Response Object

`chat.ask` returns a `RubyLLM::Message`:

```ruby
response = chat.ask("Hello")

response.content        # The text response
response.role           # "assistant"
response.input_tokens   # Tokens in prompt
response.output_tokens  # Tokens in response
response.model_id       # Model that responded

# Raw provider response for debugging
response.raw.status
response.raw.headers
response.raw.body
```
</response_object>

<conversation_context>
## Conversation Context

Chats automatically maintain context:

```ruby
chat = RubyLLM.chat
chat.ask("My name is Alice")
chat.ask("I live in Paris")
chat.ask("What's my name and where do I live?")
# => "Your name is Alice and you live in Paris."

# Access message history
chat.messages.each do |msg|
  puts "#{msg.role}: #{msg.content}"
end
```
</conversation_context>

<system_prompts>
## System Prompts

```ruby
# Set system prompt
chat.with_system("You are a helpful coding assistant. Be concise.")

# Or via method
chat = RubyLLM.chat
chat.add_system("Always respond in JSON format.")
```
</system_prompts>

<parameters>
## Chat Parameters

```ruby
# Limit response length
chat.with_params(max_tokens: 500)

# Control randomness
chat.with_params(temperature: 0.7)

# JSON mode (valid JSON, but no schema enforcement)
chat.with_params(response_format: { type: 'json_object' })

# Chain parameters
chat.with_params(max_tokens: 500, temperature: 0.3)
    .ask("Generate a haiku")
```
</parameters>

<callbacks>
## Event Callbacks

```ruby
chat = RubyLLM.chat

# When first chunk arrives
chat.on_new_message do
  print "Assistant: "
end

# When response complete
chat.on_end_message do |message|
  if message
    puts "\n[#{message.input_tokens + message.output_tokens} tokens]"
  end
end

# When tool is called
chat.on_tool_call do |tool_call|
  puts "Calling: #{tool_call.name}"
end

# When tool returns
chat.on_tool_result do |result|
  puts "Result: #{result}"
end

chat.ask("Hello!") { |chunk| print chunk.content }
```
</callbacks>

<complete_method>
## The complete() Method

For Rails integration, use `complete` instead of `ask` when you need streaming with persistence:

```ruby
# ask: Creates user message, makes request, returns response
response = chat.ask("Hello")

# complete: Just makes request for the last user message
# Use when user message is already persisted
chat.messages.create!(role: 'user', content: "Hello")
chat.complete do |chunk|
  print chunk.content
end
```
</complete_method>

<multi_model>
## Switching Models Mid-Conversation

```ruby
chat = RubyLLM.chat(model: 'gpt-4.1-mini')
chat.ask("Simple question")

# Switch to more powerful model
chat.model = 'gpt-4.1'
chat.ask("Complex reasoning task")
```
</multi_model>

<decision_tree>
## When to Use What

**Simple Q&A:** `chat.ask("question")`

**Multi-turn conversation:** Create chat once, call `ask` multiple times

**With files:** `chat.ask("prompt", with: "file.pdf")`

**Streaming:** `chat.ask("prompt") { |chunk| ... }`

**Rails persistence:** Use `acts_as_chat` models (see rails-integration.md)
</decision_tree>
