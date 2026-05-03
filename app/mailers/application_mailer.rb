# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ApplicationMailer.default_sender }

  def self.default_sender
    ENV["MAILER_DEFAULT_FROM"].presence || "noreply@example.com"
  end
end
