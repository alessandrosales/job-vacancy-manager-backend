<overview>
Embeddings convert text into numerical vectors for semantic search, similarity comparison, and RAG (Retrieval-Augmented Generation) applications.
</overview>

<basic_usage>
## Basic Usage

```ruby
# Single text
embedding = RubyLLM.embed("Ruby is elegant and expressive")

puts embedding.vectors.first.length  # => 1536 (for text-embedding-3-small)
puts embedding.model                  # Model used
puts embedding.input_tokens           # Tokens consumed
```
</basic_usage>

<batch_embeddings>
## Batch Embeddings

More efficient than individual calls:

```ruby
texts = ["Ruby", "Python", "JavaScript"]
embeddings = RubyLLM.embed(texts)

puts embeddings.vectors.length  # => 3
puts embeddings.input_tokens    # Total tokens

# Access each vector
texts.zip(embeddings.vectors).each do |text, vector|
  puts "#{text}: #{vector.first(5)}..."
end
```
</batch_embeddings>

<choosing_models>
## Choosing Models

```ruby
# OpenAI (default)
RubyLLM.embed("text", model: 'text-embedding-3-small')  # Faster, cheaper
RubyLLM.embed("text", model: 'text-embedding-3-large')  # Higher quality

# Configure default
RubyLLM.configure do |config|
  config.default_embedding_model = 'text-embedding-3-small'
end
```
</choosing_models>

<similarity>
## Similarity Calculation

Use cosine similarity to compare vectors:

```ruby
def cosine_similarity(a, b)
  dot_product = a.zip(b).sum { |x, y| x * y }
  magnitude_a = Math.sqrt(a.sum { |x| x * x })
  magnitude_b = Math.sqrt(b.sum { |x| x * x })
  dot_product / (magnitude_a * magnitude_b)
end

# Compare texts
emb1 = RubyLLM.embed("Ruby programming").vectors.first
emb2 = RubyLLM.embed("Python programming").vectors.first
emb3 = RubyLLM.embed("Cooking recipes").vectors.first

puts cosine_similarity(emb1, emb2)  # High (both programming)
puts cosine_similarity(emb1, emb3)  # Low (different topics)
```
</similarity>

<rails_caching>
## Rails Caching

Cache embeddings to avoid recomputation:

```ruby
class Document < ApplicationRecord
  def embedding
    Rails.cache.fetch("doc:#{id}:embedding:v1", expires_in: 1.week) do
      RubyLLM.embed(content).vectors.first
    end
  end
end
```
</rails_caching>

<pgvector>
## PostgreSQL with pgvector

Store embeddings for fast similarity search:

```ruby
# Migration
class AddEmbeddingToDocuments < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'vector'
    add_column :documents, :embedding, :vector, limit: 1536
    add_index :documents, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end

# Model
class Document < ApplicationRecord
  def generate_embedding!
    vector = RubyLLM.embed(content).vectors.first
    update!(embedding: vector)
  end

  # Find similar documents
  scope :similar_to, ->(embedding, limit: 10) {
    order(Arel.sql("embedding <=> '#{embedding}'")).limit(limit)
  }
end

# Usage
doc = Document.find(1)
similar = Document.similar_to(doc.embedding, limit: 5)
```
</pgvector>

<rag_pattern>
## RAG Pattern

Retrieve relevant context before asking:

```ruby
class RagAssistant
  def ask(question)
    # 1. Embed the question
    question_embedding = RubyLLM.embed(question).vectors.first

    # 2. Find relevant documents
    relevant_docs = Document.similar_to(question_embedding, limit: 3)

    # 3. Build context
    context = relevant_docs.map(&:content).join("\n\n")

    # 4. Ask with context
    chat = RubyLLM.chat
    chat.with_system("Answer based on this context:\n#{context}")
    chat.ask(question)
  end
end

assistant = RagAssistant.new
response = assistant.ask("What is our refund policy?")
```
</rag_pattern>

<async_batch>
## Async Batch Processing

For large datasets:

```ruby
require 'async'

def generate_embeddings(texts, batch_size: 100)
  Async do
    embeddings = []

    texts.each_slice(batch_size) do |batch|
      task = Async do
        RubyLLM.embed(batch).vectors
      end
      embeddings.concat(task.wait)
    end

    texts.zip(embeddings)
  end.wait
end

# Process 1000 documents
texts = Document.pluck(:content)
pairs = generate_embeddings(texts)
```
</async_batch>

<best_practices>
## Best Practices

1. **Batch embeddings** - Multiple texts in one call is cheaper
2. **Cache results** - Embeddings don't change, cache aggressively
3. **Use pgvector** - For production similarity search
4. **Chunk long text** - Split documents into paragraphs
5. **Version cache keys** - Include model version in cache key
</best_practices>
