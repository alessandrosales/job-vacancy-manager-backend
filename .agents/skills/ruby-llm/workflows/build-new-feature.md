# Workflow: Build New AI Feature

<required_reading>
**Read these reference files NOW:**
1. references/getting-started.md
2. references/chat-api.md
3. references/providers.md
</required_reading>

<process>
## Step 1: Verify Configuration

Check RubyLLM is configured:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  # Add other providers as needed
end
```

Test in console:
```bash
bin/rails console
> RubyLLM.chat.ask("Hello")
```

## Step 2: Choose Feature Type

**Chat/Conversation:**
```ruby
chat = RubyLLM.chat(model: 'gpt-4.1')
response = chat.ask("Your prompt here")
puts response.content
```

**Multi-turn conversation:**
```ruby
chat = RubyLLM.chat
chat.ask("My name is Alice")
chat.ask("What's my name?")  # Remembers context
```

**With files (images, PDFs, audio):**
```ruby
chat.ask("What's in this image?", with: "photo.jpg")
chat.ask("Summarize this document", with: "report.pdf")
```

**Embeddings:**
```ruby
embedding = RubyLLM.embed("Ruby is elegant")
puts embedding.vectors.first.length  # => 1536
```

**Image generation:**
```ruby
image = RubyLLM.paint("A sunset over mountains")
image.save("sunset.png")
```

**Audio transcription:**
```ruby
transcription = RubyLLM.transcribe("meeting.wav")
puts transcription.text
```

## Step 3: Implement the Feature

Create a service or model method:

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  def summarize
    chat = RubyLLM.chat(model: 'gpt-4.1')
    response = chat.ask("Summarize this document:", with: file.path)
    update!(summary: response.content)
  end
end
```

Or a dedicated class:

```ruby
# app/models/document/summarizer.rb
class Document::Summarizer
  def initialize(document)
    @document = document
  end

  def call
    response = chat.ask(prompt, with: @document.file.path)
    @document.update!(summary: response.content)
    response.content
  end

  private

  def chat = RubyLLM.chat(model: 'gpt-4.1')
  def prompt = "Summarize this document in 3 bullet points:"
end
```

## Step 4: Add Error Handling

```ruby
def summarize
  response = chat.ask(prompt, with: file.path)
  update!(summary: response.content)
rescue RubyLLM::RateLimitError
  # Retry later
  SummarizeJob.set(wait: 1.minute).perform_later(id)
rescue RubyLLM::Error => e
  Sentry.capture_exception(e) if defined?(Sentry)
  update!(summary_error: e.message)
end
```

## Step 5: Verify

```bash
# Test in console
bin/rails console
> Document.first.summarize

# Run tests
bin/rails test test/models/document_test.rb
```
</process>

<anti_patterns>
Avoid:
- Hardcoding API keys (use ENV variables)
- Ignoring errors (always rescue RubyLLM::Error)
- Synchronous LLM calls in controllers (use background jobs)
- Not setting request_timeout for long operations
</anti_patterns>

<success_criteria>
Feature is complete when:
- [ ] Configuration verified in console
- [ ] Feature works with test input
- [ ] Errors handled gracefully
- [ ] Wrapped in background job if slow
- [ ] Tests passing
</success_criteria>
