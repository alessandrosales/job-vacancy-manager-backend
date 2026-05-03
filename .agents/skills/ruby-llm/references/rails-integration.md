<overview>
RubyLLM provides deep Rails integration with `acts_as_chat`, `acts_as_message`, and `acts_as_tool_call` helpers that automatically persist conversations to your database.
</overview>

<installation>
## Installation

Run the generator:

```bash
bin/rails generate ruby_llm:install
```

This creates:
- Migration for `chats`, `messages`, `tool_calls` tables
- Initializer at `config/initializers/ruby_llm.rb`

Optional chat UI:
```bash
bin/rails generate ruby_llm:chat_ui
```

Run migrations:
```bash
bin/rails db:migrate
```
</installation>

<model_setup>
## Model Setup

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

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call
end
```

**Important:** Don't validate `content` presence on messages - assistant messages are created empty during streaming.
</model_setup>

<basic_usage>
## Basic Usage

```ruby
# Create a chat
chat = Chat.create!(model: 'gpt-4.1', user: current_user)

# Ask questions - messages are auto-persisted
response = chat.ask("What is Ruby?")
puts response.content

# Continue conversation
chat.ask("Tell me more about metaprogramming")

# Check message count
chat.messages.count  # => 4 (2 user, 2 assistant)
```
</basic_usage>

<custom_associations>
## Custom Associations

If you need different class/association names:

```ruby
# app/models/conversation.rb
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages,
               message_class: 'ChatMessage'

  belongs_to :user
end

# app/models/chat_message.rb
class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,
                  chat_class: 'Conversation',
                  chat_foreign_key: 'conversation_id'
end
```
</custom_associations>

<streaming>
## Streaming with Persistence

Add broadcasting to models:

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
      if chunk.content
        chat.messages.last.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
```
</streaming>

<ask_vs_complete>
## ask() vs complete()

```ruby
# ask() creates user message, makes request, persists response
chat.ask("Hello")

# complete() just makes request for last user message
# Use when message is already persisted
chat.messages.create!(role: 'user', content: "Hello")
chat.complete { |chunk| ... }
```

In controllers with streaming, use `complete`:

```ruby
def create
  @chat.messages.create!(role: 'user', content: params[:content])
  ChatStreamJob.perform_later(@chat.id)  # Job calls complete()
  head :ok
end
```
</ask_vs_complete>

<with_tools>
## Tools with Persistence

```ruby
# Tool calls are automatically persisted
chat = Chat.create!(model: 'gpt-4.1')
chat.with_tool(Weather)
chat.ask("Weather in Paris?")

# Access tool call history
message = chat.messages.last
message.tool_calls.each do |tc|
  puts "#{tc.name}: #{tc.arguments} => #{tc.result}"
end
```
</with_tools>

<structured_output>
## Structured Output with Persistence

```ruby
class PersonSchema < RubyLLM::Schema
  string :name
  integer :age
  string :city, required: false
end

chat = Chat.create!(model: 'gpt-4.1')
response = chat.with_schema(PersonSchema).ask("Generate a person from Paris")

# Response is parsed Hash
puts response.content  # => {"name" => "Marie", "age" => 28, "city" => "Paris"}

# Stored as JSON string in database
message = chat.messages.last
puts message.content  # => '{"name":"Marie","age":28,"city":"Paris"}'
```
</structured_output>

<controller_pattern>
## Controller Pattern

```ruby
# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  def index
    @chats = current_user.chats.recent
  end

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
</controller_pattern>

<views>
## View Templates

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
</views>

<file_attachments>
## File Attachments with ActiveStorage

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :files
end

# Usage
chat.ask("Summarize this document", with: message.files.first.path)
```
</file_attachments>
