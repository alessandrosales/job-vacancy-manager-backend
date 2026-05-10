# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ApplicationMailer.default_sender }

  def self.default_sender
    MailerEnv.transactional_from.presence || "noreply@example.com"
  end
end
