<overview>
Streaming delivers LLM responses incrementally as they're generated, providing immediate feedback to users instead of waiting for the complete response.
</overview>

<basic_streaming>
## Basic Streaming

Pass a block to `ask`:

```ruby
chat = RubyLLM.chat

chat.ask("Tell me a story") do |chunk|
  print chunk.content  # Prints as it arrives
end

# After block completes, full response is available
puts chat.messages.last.content
```

The block receives `RubyLLM::Chunk` objects:
- `chunk.content` - Text fragment (may be nil for tool calls)
- `chunk.tool_calls` - Tool call data if applicable
</basic_streaming>

<streaming_with_tools>
## Streaming with Tools

Handle tool calls during streaming:

```ruby
chat.with_tool(Weather)

chat.ask("What's the weather in Berlin?") do |chunk|
  if chunk.tool_calls
    puts "\n[Calling: #{chunk.tool_calls.values.first.name}]"
  elsif chunk.content
    print chunk.content
  end
end
```

The stream pauses while tools execute, then resumes.
</streaming_with_tools>

<sse>
## Server-Sent Events (SSE)

For non-Rails or API-only applications:

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

**JavaScript client:**
```javascript
const eventSource = new EventSource('/stream_chat?prompt=Hello');
eventSource.onmessage = (event) => {
  document.getElementById('output').innerHTML += JSON.parse(event.data);
};
eventSource.addEventListener('complete', () => eventSource.close());
```
</sse>

<turbo_streams>
## Rails Turbo Streams

**Model setup:**

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

**Background job:**

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
  end
end
```

**View:**

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from [@chat, "messages"] %>

<div id="messages">
  <%= render @chat.messages %>
</div>

<%= form_with url: chat_messages_path(@chat), method: :post do |f| %>
  <%= f.text_area :content %>
  <%= f.submit "Send" %>
<% end %>
```

**Message partial:**

```erb
<%# app/views/messages/_message.html.erb %>
<div id="<%= dom_id(message) %>">
  <strong><%= message.role.titleize %>:</strong>
  <div id="<%= dom_id(message, 'content') %>">
    <%= simple_format(message.content) %>
  </div>
</div>
```
</turbo_streams>

<callbacks>
## Event Callbacks

Fine-grained control over streaming lifecycle:

```ruby
chat = RubyLLM.chat

chat.on_new_message do
  # First chunk received - show typing indicator
  print "Assistant: "
end

chat.on_end_message do |message|
  # Complete - update UI, log tokens
  if message
    puts "\n[#{message.input_tokens + message.output_tokens} tokens]"
  end
end

chat.ask("Hello!") { |chunk| print chunk.content }
```
</callbacks>

<error_handling>
## Error Handling

Preserve partial content on errors:

```ruby
begin
  accumulated = ""

  chat.ask("Generate long content...") do |chunk|
    print chunk.content
    accumulated << chunk.content.to_s
  end
rescue RubyLLM::RateLimitError
  puts "\nRate limited. Partial content: #{accumulated}"
rescue RubyLLM::Error => e
  puts "\nStream failed: #{e.message}"
  puts "Got: #{accumulated}"
end
```
</error_handling>

<decision_tree>
## When to Use What

**Console/scripts:** Basic block streaming

**API endpoints:** SSE with EventSource

**Rails with Hotwire:** Turbo Streams + background job

**Complex UI:** Callbacks for typing indicators, progress
</decision_tree>

<anti_patterns>
## Anti-Patterns

```ruby
# Bad: Streaming in controller (blocks request)
def create
  chat.ask(params[:message]) { |c| ... }  # Request hangs!
end

# Good: Background job
def create
  ChatStreamJob.perform_later(chat.id)
  head :ok
end

# Bad: Ignoring partial content on error
rescue RubyLLM::Error
  render json: { error: "Failed" }
end

# Good: Preserve what you got
rescue RubyLLM::Error => e
  render json: { error: e.message, partial: accumulated }
end
```
</anti_patterns>
