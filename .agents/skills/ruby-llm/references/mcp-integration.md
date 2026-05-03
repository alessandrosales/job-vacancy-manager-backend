<overview>
RubyLLM::MCP enables Ruby applications to connect to Model Context Protocol (MCP) servers, using their tools, resources, and prompts in LLM conversations.
</overview>

<installation>
## Installation

```ruby
gem 'ruby_llm-mcp'
```

```bash
bundle install
```
</installation>

<basic_connection>
## Basic Connection

```ruby
require 'ruby_llm/mcp'

# Connect to an MCP server
client = RubyLLM::MCP.client(
  name: "filesystem",
  transport_type: :stdio,
  config: {
    command: "npx",
    args: ["@modelcontextprotocol/server-filesystem", "/path/to/directory"]
  }
)
```
</basic_connection>

<using_tools>
## Using MCP Tools

```ruby
# List available tools
tools = client.tools
tools.each do |tool|
  puts "#{tool.name}: #{tool.description}"
end

# Use in chat
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_tools(*client.tools)

response = chat.ask("List all Ruby files in the project")
puts response.content
```
</using_tools>

<specific_tool>
## Using a Specific Tool

```ruby
# Get one tool
search_tool = client.tool("search_files")

# Add only this tool
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_tools(search_tool)

response = chat.ask("Search for config files")
```
</specific_tool>

<resources>
## Using MCP Resources

```ruby
# List resources
resources = client.resources
resources.each do |r|
  puts "#{r.name}: #{r.description}"
end

# Add resource context to chat
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_resource(client.resource("project_overview"))
chat.ask("Summarize the project structure")
```
</resources>

<prompts>
## Using MCP Prompts

```ruby
# List prompts
prompts = client.prompts
prompts.each do |p|
  puts "#{p.name}: #{p.description}"
end

# Use prompt template
chat = RubyLLM.chat(model: 'gpt-4.1')
chat.with_prompt(
  client.prompt("code_review"),
  arguments: { focus: "security" }
)
chat.ask("Review this code")
```
</prompts>

<combined>
## Combining Tools, Resources, and Prompts

```ruby
chat = RubyLLM.chat(model: 'gpt-4.1')

# Add capabilities
chat.with_tools(*client.tools)
chat.with_resource(client.resource("project_docs"))
chat.with_prompt(
  client.prompt("analysis"),
  arguments: { focus: "performance" }
)

response = chat.ask("Analyze the project")
```
</combined>

<rails_integration>
## Rails Integration

```ruby
# app/jobs/mcp_analysis_job.rb
class McpAnalysisJob < ApplicationJob
  queue_as :default

  def perform(project_path)
    client = RubyLLM::MCP.client(
      name: "filesystem",
      transport_type: :stdio,
      config: {
        command: "npx",
        args: ["@modelcontextprotocol/server-filesystem", project_path]
      }
    )

    chat = RubyLLM.chat(model: 'gpt-4.1')
    chat.with_tools(*client.tools)

    analysis = chat.ask("Analyze code structure and recommendations")

    AnalysisResult.create!(
      project_path: project_path,
      analysis: analysis.content
    )
  ensure
    client&.close
  end
end
```
</rails_integration>

<establish_connection>
## Connection Block Pattern

```ruby
RubyLLM::MCP.establish_connection do |clients|
  # Add roots for filesystem access
  clients.each { |c| c.roots.add("/path/to/project") }

  chat = RubyLLM.chat(model: 'gpt-4.1')
  chat.with_tools(*clients.tools)

  response = chat.ask("Analyze the project")
  puts response.content
end
# Connection automatically closed
```
</establish_connection>

<tool_execution>
## Direct Tool Execution

```ruby
# Execute tool directly
tool = client.tool("read_file")
result = tool.execute(path: "README.md")
puts result

# With structured output validation
weather = client.tool("get_weather")
result = weather.execute(location: "San Francisco")
puts result.temperature
```
</tool_execution>

<best_practices>
## Best Practices

1. **Close connections** - Use blocks or ensure cleanup
2. **Error handling** - MCP servers can fail
3. **Tool selection** - Add only needed tools
4. **Timeout configuration** - Set appropriate timeouts
5. **Background jobs** - Don't block web requests
</best_practices>
