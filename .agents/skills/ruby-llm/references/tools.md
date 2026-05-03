<overview>
Tools (function calling) allow the LLM to invoke Ruby code during conversations. The LLM decides when to use tools based on their descriptions.
</overview>

<defining_tools>
## Defining Tools

Inherit from `RubyLLM::Tool`:

```ruby
class Weather < RubyLLM::Tool
  description "Get current weather for a location"

  param :latitude, type: 'number', desc: "Latitude coordinate"
  param :longitude, type: 'number', desc: "Longitude coordinate"

  def execute(latitude:, longitude:)
    response = WeatherAPI.fetch(latitude, longitude)
    {
      temperature: response.temperature,
      conditions: response.conditions,
      wind_speed: response.wind_speed
    }
  end
end
```

**Key components:**
- `description` - Explains when the LLM should use this tool
- `param` - Defines parameters with type and description
- `execute` - The Ruby code that runs
</defining_tools>

<parameter_types>
## Parameter Types

```ruby
class MyTool < RubyLLM::Tool
  description "Demonstrates parameter types"

  # Basic types
  param :name, type: 'string', desc: "User name"
  param :age, type: 'integer', desc: "User age"
  param :price, type: 'number', desc: "Price (float)"
  param :active, type: 'boolean', desc: "Is active?"

  # Optional parameters
  param :nickname, type: 'string', desc: "Optional nickname", required: false

  # Enums
  param :status, type: 'string', desc: "Status", enum: %w[pending active done]

  # Arrays
  param :tags, type: 'array', desc: "Tags" do
    string
  end

  # Nested objects
  param :address, type: 'object' do
    string :street, desc: "Street address"
    string :city, desc: "City"
    string :zip, desc: "ZIP code"
  end

  def execute(**params)
    # Use params
  end
end
```
</parameter_types>

<using_tools>
## Using Tools

```ruby
# Attach single tool
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_tool(Weather)

# Attach multiple tools
chat.with_tools(Weather, Calculator, Search)

# Replace all tools
chat.with_tools(NewTool, replace: true)

# Clear all tools
chat.with_tools(replace: true)

# Ask - LLM decides whether to use tools
response = chat.ask("What's the weather in Berlin at 52.52, 13.40?")
puts response.content
# => "The current weather in Berlin is 15°C with light clouds..."
```
</using_tools>

<error_handling>
## Error Handling in Tools

**Return errors, don't raise exceptions:**

```ruby
class Weather < RubyLLM::Tool
  def execute(latitude:, longitude:)
    # Validate input
    return { error: "Latitude must be between -90 and 90" } unless (-90..90).include?(latitude)

    # Call API
    response = WeatherAPI.fetch(latitude, longitude)
    { temperature: response.temperature }

  rescue Faraday::ConnectionFailed
    # Recoverable error - let LLM handle it
    { error: "Weather service temporarily unavailable" }

  rescue ActiveRecord::RecordNotFound => e
    # Unrecoverable - raise to halt
    raise e
  end
end
```

**Rule:** Return `{ error: "message" }` for recoverable errors. Raise exceptions only for unrecoverable failures.
</error_handling>

<halt_pattern>
## The Halt Pattern

Skip LLM synthesis and return raw data:

```ruby
class ProductSearch < RubyLLM::Tool
  description "Search products in catalog"
  param :query, desc: "Search query"

  def execute(query:)
    products = Product.search(query).limit(10)

    # halt! returns data directly, skipping LLM response
    halt! products.map { |p|
      { id: p.id, name: p.name, price: p.price }
    }
  end
end

# Usage - response.content is raw product data
response = chat.with_tool(ProductSearch).ask("Find laptops")
products = response.content  # Array of products, not prose
```

**Use halt! when:**
- Returning structured data for UI components
- Populating forms or tables
- API responses that don't need LLM prose
</halt_pattern>

<tool_callbacks>
## Tool Callbacks

Monitor tool execution:

```ruby
chat = RubyLLM.chat

chat.on_tool_call do |tool_call|
  puts "Tool: #{tool_call.name}"
  puts "Args: #{tool_call.arguments}"
end

chat.on_tool_result do |result|
  puts "Result: #{result}"
end

chat.with_tool(Weather).ask("Weather in Tokyo?")
```
</tool_callbacks>

<manual_schema>
## Manual JSON Schema

For full control, provide schema directly:

```ruby
class Lookup < RubyLLM::Tool
  description "Performs catalog lookups"

  params schema: {
    type: "object",
    properties: {
      sku: { type: "string", description: "Product SKU" },
      locale: { type: "string", description: "Country code", default: "US" }
    },
    required: ["sku"],
    additionalProperties: false
  }

  def execute(sku:, locale: "US")
    Catalog.find_by(sku: sku, locale: locale)
  end
end
```
</manual_schema>

<best_practices>
## Best Practices

1. **Clear descriptions** - "Get current weather for coordinates" not "Does weather stuff"
2. **Typed parameters** - Always specify `type` and `desc`
3. **Structured returns** - Return Hashes, not strings
4. **Fast execution** - Keep under 5 seconds
5. **Graceful errors** - Return `{ error: ... }`, don't raise
6. **Input validation** - Check inputs before processing
</best_practices>

<anti_patterns>
## Anti-Patterns

```ruby
# Bad: Vague description
description "Does stuff with data"

# Good: Clear when to use
description "Search products by name, category, or price range"

# Bad: Raising for recoverable errors
def execute(query:)
  raise "No results" if results.empty?
end

# Good: Return error object
def execute(query:)
  return { error: "No products found for '#{query}'" } if results.empty?
end

# Bad: Returning strings
def execute(...)
  "The temperature is 15 degrees"
end

# Good: Return structured data
def execute(...)
  { temperature: 15, unit: "celsius" }
end
```
</anti_patterns>
