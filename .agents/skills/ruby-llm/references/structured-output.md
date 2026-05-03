<overview>
Structured output ensures LLM responses conform to a defined JSON schema. RubyLLM supports both schema classes via `ruby_llm-schema` gem and manual JSON schemas.
</overview>

<json_mode_vs_schema>
## JSON Mode vs Structured Output

**JSON Mode:** Guarantees valid JSON, but no specific structure:
```ruby
chat = RubyLLM.chat.with_params(response_format: { type: 'json_object' })
response = chat.ask("List 3 languages with years")
# Could return any JSON structure
```

**Structured Output:** Guarantees exact schema:
```ruby
chat = RubyLLM.chat.with_schema(LanguagesSchema)
response = chat.ask("List 3 languages with years")
# Returns exactly: {"languages": [{"name": "...", "year": ...}]}
```

**Always use `with_schema` when you need predictable structure.**
</json_mode_vs_schema>

<schema_dsl>
## Defining Schemas

Add the gem:
```ruby
gem 'ruby_llm-schema'
```

Define schemas:

```ruby
class PersonSchema < RubyLLM::Schema
  string :name, description: "Person's full name"
  integer :age, description: "Age in years"
  string :email, format: 'email'
  string :city, required: false  # Optional field
end

# Usage
chat = RubyLLM.chat
response = chat.with_schema(PersonSchema)
               .ask("Extract: John Doe, 35, john@example.com")

puts response.content['name']   # => "John Doe"
puts response.content['age']    # => 35
puts response.content['email']  # => "john@example.com"
```
</schema_dsl>

<schema_types>
## Schema Field Types

```ruby
class ComprehensiveSchema < RubyLLM::Schema
  # Basic types
  string :name
  integer :count
  number :price  # Float
  boolean :active

  # With constraints
  string :status, enum: %w[pending active done]
  integer :rating, minimum: 1, maximum: 5

  # Arrays
  array :tags do
    string
  end

  array :scores do
    integer
  end

  # Nested objects
  object :address do
    string :street
    string :city
    string :zip
  end

  # Array of objects
  array :contacts do
    object do
      string :name
      string :email
      string :role, enum: %w[primary secondary]
    end
  end
end
```
</schema_types>

<nested_schemas>
## Nested Schemas

```ruby
class EmployeeSchema < RubyLLM::Schema
  string :name
  string :role, enum: %w[developer designer manager]
  array :skills, of: :string
end

class CompanySchema < RubyLLM::Schema
  string :name

  array :employees do
    object EmployeeSchema  # Reuse schema
  end

  object :metadata do
    integer :founded
    string :industry
  end
end

response = chat.with_schema(CompanySchema)
               .ask("Generate a small tech startup")

response.content["employees"].each do |emp|
  puts "#{emp['name']} - #{emp['role']}"
end
```
</nested_schemas>

<manual_schema>
## Manual JSON Schema

For full control:

```ruby
person_schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' },
    hobbies: {
      type: 'array',
      items: { type: 'string' }
    }
  },
  required: ['name', 'age', 'hobbies'],
  additionalProperties: false  # Required for OpenAI
}

chat = RubyLLM.chat
response = chat.with_schema(person_schema)
               .ask("Generate a person who likes Ruby")

puts response.content  # => {"name" => "Bob", "age" => 25, "hobbies" => [...]}
```
</manual_schema>

<multi_turn>
## Multi-Turn with Schemas

Switch schemas during conversation:

```ruby
chat = RubyLLM.chat

# Start with person schema
chat.with_schema(PersonSchema)
person = chat.ask("Generate a French person")

# Remove schema for free-form
chat.with_schema(nil)
analysis = chat.ask("What careers suit this person?")

# Different schema
class CareerSchema < RubyLLM::Schema
  string :title
  array :steps, of: :string
  integer :years_required
end

chat.with_schema(CareerSchema)
career = chat.ask("Structure a career plan for them")
```
</multi_turn>

<rails_persistence>
## Rails Persistence

With `acts_as_chat`:

```ruby
chat = Chat.create!(model: 'gpt-4.1')
response = chat.with_schema(PersonSchema)
               .ask("Generate a person")

# Response is parsed Hash
puts response.content  # => {"name" => "Marie", ...}

# Stored as JSON string
message = chat.messages.last
puts message.content  # => '{"name":"Marie",...}'

# Parse when reading
data = JSON.parse(message.content)
```
</rails_persistence>

<model_support>
## Model Support

Not all models support structured output. Check capability:

```ruby
model = RubyLLM.models.find('gpt-4.1')
puts model.supports_structured_output?

# If unsupported, provider returns error
chat = RubyLLM.chat(model: 'old-model')
chat.with_schema(schema)
response = chat.ask('Generate')  # May error
```

**Models with good structured output support:**
- OpenAI: gpt-4.1, gpt-4.1-mini
- Anthropic: claude-sonnet-4-5, claude-3-5-haiku
- Gemini: gemini-2.0-flash, gemini-2.5-pro
</model_support>

<best_practices>
## Best Practices

1. **Add descriptions** - Help the LLM understand field purpose
2. **Use enums** - Constrain string values when possible
3. **Mark optional fields** - Use `required: false`
4. **Use additionalProperties: false** - Required for OpenAI
5. **Parse response.content** - It's already a Hash, not JSON string
</best_practices>
