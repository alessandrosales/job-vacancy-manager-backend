<overview>
RubyLLM supports image generation via `paint` and audio transcription via `transcribe`, providing unified APIs across providers.
</overview>

<image_generation>
## Image Generation

```ruby
# Basic generation
image = RubyLLM.paint("A sunset over mountains in watercolor style")

# Save to file
image.save("sunset.png")

# Get URL (if provider returns URL)
puts image.url if image.url

# Get binary data (for storage)
blob = image.to_blob if image.base64?
```
</image_generation>

<image_options>
## Image Options

```ruby
# Specific model
image = RubyLLM.paint(
  "A futuristic cityscape",
  model: 'gpt-image-1'  # DALL-E 3
)

# With size
image = RubyLLM.paint(
  "Portrait of a robot",
  model: 'gpt-image-1',
  size: '1024x1792'  # Portrait orientation
)

# Google Imagen
image = RubyLLM.paint(
  "Cyberpunk city at night",
  model: 'imagen-3.0-generate-002'
)
```
</image_options>

<revised_prompt>
## Revised Prompts

Some models enhance your prompt:

```ruby
image = RubyLLM.paint("A dog")

if image.revised_prompt
  puts "Original: A dog"
  puts "Enhanced: #{image.revised_prompt}"
  # => "A golden retriever puppy playing in a sunny meadow..."
end
```
</revised_prompt>

<active_storage>
## Rails Active Storage

```ruby
class Product < ApplicationRecord
  has_one_attached :generated_image

  def generate_image!(prompt)
    image = RubyLLM.paint(prompt)

    generated_image.attach(
      io: StringIO.new(image.to_blob),
      filename: "#{slug}-#{Time.current.to_i}.png",
      content_type: image.mime_type || 'image/png'
    )

    update!(
      image_prompt: prompt,
      image_revised_prompt: image.revised_prompt
    )
  rescue RubyLLM::Error => e
    update!(image_error: e.message)
  end
end
```
</active_storage>

<prompt_engineering>
## Image Prompt Tips

```ruby
# Simple - generic results
RubyLLM.paint("dog")

# Detailed - better results
RubyLLM.paint(
  "A photorealistic image of a golden retriever puppy " \
  "playing fetch in a sunny park, shallow depth of field, " \
  "captured with a DSLR camera"
)

# With style
RubyLLM.paint(
  "A majestic mountain range, " \
  "oil painting in the style of Bob Ross"
)
```
</prompt_engineering>

<audio_transcription>
## Audio Transcription

```ruby
transcription = RubyLLM.transcribe("meeting.wav")

puts transcription.text   # Full transcription
puts transcription.model  # Model used (e.g., "whisper-1")
```
</audio_transcription>

<audio_formats>
## Supported Audio Formats

- MP3
- MP4
- M4A
- WAV
- WebM
- OGG
- FLAC
</audio_formats>

<transcription_options>
## Transcription Options

```ruby
# With language hint
transcription = RubyLLM.transcribe(
  "audio.mp3",
  language: "en"
)

# Specific model
transcription = RubyLLM.transcribe(
  "audio.mp3",
  model: "whisper-1"
)
```
</transcription_options>

<transcription_errors>
## Error Handling

```ruby
begin
  transcription = RubyLLM.transcribe("audio.mp3")
  puts transcription.text
rescue RubyLLM::BadRequestError => e
  puts "Invalid file: #{e.message}"
rescue RubyLLM::TimeoutError => e
  puts "Transcription timed out: #{e.message}"
rescue RubyLLM::Error => e
  puts "Failed: #{e.message}"
end
```
</transcription_errors>

<rails_transcription>
## Rails Integration

```ruby
class Recording < ApplicationRecord
  has_one_attached :audio_file

  def transcribe!
    return if transcription.present?

    result = RubyLLM.transcribe(audio_file.download)
    update!(transcription: result.text)
  rescue RubyLLM::Error => e
    update!(transcription_error: e.message)
  end
end

# In background job
class TranscriptionJob < ApplicationJob
  def perform(recording_id)
    Recording.find(recording_id).transcribe!
  end
end
```
</rails_transcription>

<default_models>
## Configure Defaults

```ruby
RubyLLM.configure do |config|
  config.default_image_model = 'gpt-image-1'
  config.default_transcription_model = 'whisper-1'
end
```
</default_models>
