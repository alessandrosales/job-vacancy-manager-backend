# Workflow: Add Rails Chat Integration

<required_reading>
**Read these reference files NOW:**
1. references/rails-integration.md
2. references/streaming.md
3. references/chat-api.md
</required_reading>

<process>
## Step 1: Run Generator

```bash
bin/rails generate ruby_llm:install
```

This creates:
- Migration for chats, messages, tool_calls tables
- Initializer at `config/initializers/ruby_llm.rb`

Run migration:
```bash
bin/rails db:migrate
```

## Step 2: Configure Models

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :user, optional: true

  scope :recent, -> { order(updated_at: :desc) }
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  validates :role, presence: true
  validates :chat, presence: true
  # Do NOT validate content presence - assistant messages start empty
end

# app/models/tool_call.rb (if using tools)
class ToolCall < ApplicationRecord
  acts_as_tool_call
end
```

## Step 3: Basic Chat Usage

```ruby
# Create and use a chat
chat = Chat.create!(model: 'gpt-4.1', user: current_user)
response = chat.ask("Hello!")
puts response.content

# Continue conversation
chat.ask("Tell me more")

# Messages are automatically persisted
chat.messages.count  # => 4 (2 user, 2 assistant)
```

## Step 4: Add Streaming with Turbo Streams

Update models for broadcasting:

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

Create background job:

```ruby
# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)

    chat.complete do |chunk|
      assistant_message = chat.messages.last
      if chunk.content && assistant_message
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
```

## Step 5: Create Controller

```ruby
# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  def show
    @chat = current_user.chats.find(params[:id])
  end

  def create
    @chat = current_user.chats.create!(model: 'gpt-4.1')
    redirect_to @chat
  end
end

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

## Step 6: Create Views

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from [@chat, "messages"] %>

<h1>Chat</h1>

<div id="messages">
  <%= render @chat.messages %>
</div>

<%= form_with url: chat_messages_path(@chat), method: :post do |f| %>
  <%= f.text_area :content, placeholder: "Type a message..." %>
  <%= f.submit "Send" %>
<% end %>
```

```erb
<%# app/views/messages/_message.html.erb %>
<div id="<%= dom_id(message) %>" class="message <%= message.role %>">
  <strong><%= message.role.titleize %>:</strong>
  <div id="<%= dom_id(message, 'content') %>">
    <%= simple_format(message.content) %>
  </div>
</div>
```

## Step 7: Verify

```bash
# Test in console
bin/rails console
> chat = Chat.create!(model: 'gpt-4.1')
> chat.ask("Hello!")
> chat.messages.count

# Run server and test in browser
bin/dev
# Visit /chats/new
```
</process>

<anti_patterns>
Avoid:
- Validating message content presence (assistant messages start empty during streaming)
- Calling LLM synchronously in controllers (use background jobs)
- Forgetting Turbo Stream subscriptions in views
- Not handling job failures
</anti_patterns>

<success_criteria>
Rails chat is complete when:
- [ ] Migrations run successfully
- [ ] Chat persists messages automatically
- [ ] Streaming works via Turbo Streams
- [ ] Background job handles LLM calls
- [ ] UI updates in real-time
</success_criteria>
