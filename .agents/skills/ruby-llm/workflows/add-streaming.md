# Workflow: Add Streaming Responses

<required_reading>
**Read these reference files NOW:**
1. references/streaming.md
2. references/rails-integration.md
3. references/error-handling.md
</required_reading>

<process>
## Step 1: Basic Streaming

Pass a block to `ask`:

```ruby
chat = RubyLLM.chat

chat.ask("Tell me a story") do |chunk|
  print chunk.content  # Prints as it arrives
end
```

The block receives `RubyLLM::Chunk` objects with:
- `chunk.content` - Text fragment (may be nil for tool calls)
- `chunk.tool_calls` - Tool call data if applicable

## Step 2: Streaming with Tools

Handle tool calls during streaming:

```ruby
chat.with_tool(Weather)

chat.ask("What's the weather in Berlin?") do |chunk|
  if chunk.tool_calls
    puts "\n[Tool: #{chunk.tool_calls.values.first.name}]"
  elsif chunk.content
    print chunk.content
  end
end
```

## Step 3: Server-Sent Events (SSE)

For non-Rails or API-only apps:

```ruby
# Sinatra/Roda example
get '/stream_chat' do
  content_type 'text/event-stream'

  stream(:keep_open) do |out|
    chat = RubyLLM.chat

    begin
      chat.ask(params[:prompt]) do |chunk|
        out << "data: #{chunk.content.to_json}\n\n" if chunk.content
      end
      out << "event: complete\ndata: {}\n\n"
    rescue RubyLLM::Error => e
      out << "event: error\ndata: #{e.message.to_json}\n\n"
    ensure
      out.close
    end
  end
end
```

## Step 4: Rails with Turbo Streams

**Models with broadcasting:**

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
  broadcasts_to ->(chat) { [chat, "messages"] }
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  broadcasts_to ->(message) { [message.chat, "messages"] }

  def broadcast_append_chunk(chunk_content)
    broadcast_append_to [chat, "messages"],
      target: dom_id(self, "content"),
      html: chunk_content
  end
end
```

**Background job for streaming:**

```ruby
# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)

    chat.complete do |chunk|
      if chunk.content
        assistant_message = chat.messages.last
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
  rescue RubyLLM::Error => e
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
```

**View with Turbo subscription:**

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from [@chat, "messages"] %>

<div id="messages">
  <%= render @chat.messages %>
</div>

<%= form_with url: chat_messages_path(@chat) do |f| %>
  <%= f.text_area :content %>
  <%= f.submit "Send" %>
<% end %>
```

**Controller:**

```ruby
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  def create
    @chat = current_user.chats.find(params[:chat_id])
    @chat.messages.create!(role: 'user', content: params[:content])

    ChatStreamJob.perform_later(@chat.id)
    head :ok
  end
end
```

## Step 5: Event Callbacks

Use callbacks for complex UI updates:

```ruby
chat = RubyLLM.chat

chat.on_new_message do
  # First chunk received - show typing indicator
  print "Assistant: "
end

chat.on_end_message do |message|
  # Complete - show token usage
  puts "\n[#{message.input_tokens + message.output_tokens} tokens]"
end

chat.ask("Hello!") { |chunk| print chunk.content }
```

## Step 6: Error Handling

```ruby
begin
  accumulated = ""

  chat.ask("Generate content...") do |chunk|
    print chunk.content
    accumulated << chunk.content.to_s
  end
rescue RubyLLM::RateLimitError
  puts "\nRate limited. Got: #{accumulated}"
rescue RubyLLM::Error => e
  puts "\nStream failed: #{e.message}"
  puts "Partial: #{accumulated}"
end
```

## Step 7: Verify

```bash
# Console test
bin/rails console
> chat = RubyLLM.chat
> chat.ask("Count to 10") { |c| print c.content }

# Browser test
bin/dev
# Submit message and watch real-time updates
```
</process>

<anti_patterns>
Avoid:
- Streaming in controller actions (blocks the request)
- Not handling partial content on errors
- Forgetting Turbo Stream subscriptions
- Not closing SSE connections
</anti_patterns>

<success_criteria>
Streaming is complete when:
- [ ] Chunks arrive in real-time (console test)
- [ ] UI updates progressively (browser test)
- [ ] Errors handled with partial content preserved
- [ ] Background job processes async
- [ ] Turbo Streams connected and updating
</success_criteria>
