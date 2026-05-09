# frozen_string_literal: true

# Browser clients on another origin need CORS to call this API with +Authorization: Bearer+.
# Set +CORS_ORIGINS+ to a comma-separated list (e.g. "http://localhost:5173,https://app.example.com").
# +FRONTEND_URL+ (sem barra final) é sempre incluído na lista — evita esquecer CORS em produção.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  origins_list = ENV.fetch("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000")
    .split(",")
    .map(&:strip)
    .reject(&:blank?)

  if ENV["FRONTEND_URL"].present?
    fu = ENV["FRONTEND_URL"].strip.chomp("/")
    origins_list << fu unless origins_list.include?(fu)
  end
  origins_list.uniq!

  allow do
    origins(*origins_list)

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization],
      max_age: 600
  end
end
