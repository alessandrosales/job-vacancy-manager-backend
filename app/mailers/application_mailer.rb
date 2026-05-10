# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ApplicationMailer.default_sender }

  around_action :with_recipient_locale

  def self.default_sender
    MailerEnv.transactional_from.presence || "noreply@example.com"
  end

  private

  def with_recipient_locale
    user = params[:user]
    loc = user.respond_to?(:locale_for_mailer) ? user.locale_for_mailer : I18n.default_locale
    I18n.with_locale(loc) { yield }
  end
end
