# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailerEnv do
  around do |example|
    keys = %w[
      SMTP_DEFAULT_FROM MAILER_DEFAULT_FROM FRONTEND_URL
      MAILER_DEFAULT_URL_HOST MAILER_DEFAULT_URL_PROTOCOL MAILER_DEFAULT_URL_PORT
      SMTP_DOMAIN
    ]
    saved = keys.to_h { |k| [ k, ENV[k] ] }
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  describe ".transactional_from" do
    it "prefers SMTP_DEFAULT_FROM over MAILER_DEFAULT_FROM" do
      ENV["MAILER_DEFAULT_FROM"] = "a <a@x.com>"
      ENV["SMTP_DEFAULT_FROM"] = "b <b@y.com>"
      expect(described_class.transactional_from).to eq("b <b@y.com>")
    end

    it "falls back to MAILER_DEFAULT_FROM" do
      ENV["MAILER_DEFAULT_FROM"] = "c <c@z.com>"
      expect(described_class.transactional_from).to eq("c <c@z.com>")
    end
  end

  describe ".action_mailer_default_url_options" do
    it "uses legacy MAILER_DEFAULT_URL_* when host is set" do
      ENV["MAILER_DEFAULT_URL_HOST"] = "api.example.com"
      ENV["MAILER_DEFAULT_URL_PROTOCOL"] = "https"
      ENV["MAILER_DEFAULT_URL_PORT"] = "8443"
      ENV["FRONTEND_URL"] = "https://ignored.test"

      expect(described_class.action_mailer_default_url_options).to eq(
        host: "api.example.com",
        protocol: "https",
        port: 8443
      )
    end

    it "derives host, protocol and port from FRONTEND_URL when legacy unset" do
      ENV["FRONTEND_URL"] = "http://localhost:5173"

      expect(described_class.action_mailer_default_url_options).to eq(
        host: "localhost",
        protocol: "http",
        port: 5173
      )
    end

    it "omits default HTTPS port from FRONTEND_URL" do
      ENV["FRONTEND_URL"] = "https://hireest.com"

      expect(described_class.action_mailer_default_url_options).to eq(
        host: "hireest.com",
        protocol: "https"
      )
    end
  end

  describe ".smtp_helo_domain" do
    it "prefers SMTP_DOMAIN" do
      ENV["SMTP_DOMAIN"] = "mail.example.com"
      ENV["FRONTEND_URL"] = "https://hireest.com"

      expect(described_class.smtp_helo_domain).to eq("mail.example.com")
    end

    it "uses host from FRONTEND_URL when SMTP_DOMAIN blank" do
      ENV["FRONTEND_URL"] = "https://hireest.com"

      expect(described_class.smtp_helo_domain).to eq("hireest.com")
    end
  end
end
