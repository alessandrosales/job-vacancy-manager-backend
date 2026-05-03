# Workflow: Implement Tools/Function Calling

<required_reading>
**Read these reference files NOW:**
1. references/tools.md
2. references/chat-api.md
3. references/anti-patterns.md
</required_reading>

<process>
## Step 1: Define the Tool

Create a class inheriting from `RubyLLM::Tool`:

```ruby
# app/tools/weather.rb (or app/models/tools/weather.rb)
class Weather < RubyLLM::Tool
  description "Get current weather for a location"

  param :latitude, type: 'number', desc: "Latitude coordinate"
  param :longitude, type: 'number', desc: "Longitude coordinate"

  def execute(latitude:, longitude:)
    # Call external API
    response = WeatherAPI.fetch(latitude, longitude)
    {
      temperature: response.temperature,
      conditions: response.conditions,
      wind_speed: response.wind_speed
    }
  rescue Faraday::Error => e
    { error: "Weather service unavailable: #{e.message}" }
  end
end
```

**Key rules:**
- Use `description` to explain when to use this tool
- Use `param` with `type` and `desc` for each parameter
- Return structured data (Hash), not strings
- Return `{ error: "message" }` for recoverable errors
- Only raise exceptions for unrecoverable errors

## Step 2: Attach Tool to Chat

```ruby
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_tool(Weather)

response = chat.ask("What's the weather in Berlin? (52.52, 13.40)")
puts response.content
# => "The current weather in Berlin is 15°C with light clouds..."
```

Multiple tools:
```ruby
chat.with_tools(Weather, Calculator, SearchEngine)
```

Replace tools:
```ruby
chat.with_tools(NewTool, replace: true)
```

## Step 3: Complex Tool Parameters

Use `RubyLLM::Schema` for complex structures:

```ruby
class DataAnalyzer < RubyLLM::Tool
  description "Analyze data with various operations"

  param :data, type: 'array', desc: "Array of numbers to analyze"
  param :operations, type: 'array', desc: "Operations to perform" do
    string enum: %w[mean median sum count]
  end
  param :options, type: 'object', required: false do
    boolean :round, desc: "Round results"
    integer :precision, desc: "Decimal places"
  end

  def execute(data:, operations:, options: {})
    results = {}
    operations.each do |op|
      results[op] = calculate(data, op, options)
    end
    results
  end
end
```

## Step 4: Tool Callbacks

Monitor tool execution:

```ruby
chat = RubyLLM.chat

chat.on_tool_call do |tool_call|
  puts "Calling: #{tool_call.name}"
  puts "Args: #{tool_call.arguments}"
end

chat.on_tool_result do |result|
  puts "Result: #{result}"
end

chat.with_tool(Weather).ask("Weather in Tokyo?")
```

## Step 5: The Halt Pattern

Skip LLM synthesis and return raw tool data:

```ruby
class ProductSearch < RubyLLM::Tool
  description "Search products in catalog"
  param :query, desc: "Search query"

  def execute(query:)
    products = Product.search(query).limit(10)

    # halt! returns data directly to your app, skipping LLM response
    halt! products.map { |p| { id: p.id, name: p.name, price: p.price } }
  end
end

# In controller - get structured data for UI
chat.with_tool(ProductSearch)
response = chat.ask("Find laptops under $1000")
# response.content is the raw product array, not LLM prose
```

## Step 6: Rails Integration with Tool Calls

```ruby
# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call
end

# Tool calls are automatically persisted with acts_as_chat
chat = Chat.create!(model: 'gpt-4.1')
chat.with_tool(Weather)
chat.ask("Weather in Paris?")

# Check tool call history
chat.messages.last.tool_calls.each do |tc|
  puts "#{tc.name}: #{tc.arguments} => #{tc.result}"
end
```

## Step 7: Verify

```bash
bin/rails console
> chat = RubyLLM.chat.with_tool(Weather)
> chat.ask("What's the weather at latitude 40.7, longitude -74.0?")
```
</process>

<anti_patterns>
Avoid:
- Raising exceptions for recoverable errors (return `{ error: ... }`)
- Vague descriptions ("Does stuff" vs "Search products by name")
- Missing parameter descriptions
- Slow tool execution (keep under 5 seconds)
- Tools that return unstructured strings
</anti_patterns>

<success_criteria>
Tool is complete when:
- [ ] Clear description explains when to use it
- [ ] All parameters have types and descriptions
- [ ] Returns structured data (Hash)
- [ ] Handles errors gracefully with `{ error: ... }`
- [ ] Works with `chat.ask()` in console
- [ ] Callbacks fire correctly (if needed)
</success_criteria>
