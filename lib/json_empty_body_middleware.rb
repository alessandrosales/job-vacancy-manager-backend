# frozen_string_literal: true

require "stringio"

# POST/PATCH with Content-Type application/json but an empty body makes Rack/Rails
# JSON parsing fail with ParseError (400). Many clients send that accidentally.
# Replace empty bodies with "{}" so params resolve to {} and controllers can respond
# with normal 422 (e.g. missing :auth) instead of a low-level parse error.
class JsonEmptyBodyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["CONTENT_TYPE"].to_s.include?("application/json")
      input = env["rack.input"]
      body = input.read
      input.rewind
      if body.strip.empty?
        payload = "{}"
        env["rack.input"] = StringIO.new(payload)
        env["CONTENT_LENGTH"] = payload.bytesize.to_s
      end
    end
    @app.call(env)
  end
end
