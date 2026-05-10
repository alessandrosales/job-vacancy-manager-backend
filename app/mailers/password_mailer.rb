# frozen_string_literal: true

class PasswordMailer < ApplicationMailer
  layout false

  def reset_instructions
    @user = params[:user]
    @reset_link = FrontendUrl.password_reset_link(params[:token])
    mail(to: @user.email, subject: t(".subject"))
  end

  def password_changed
    @user = params[:user]
    mail(to: @user.email, subject: t(".subject"))
  end
end
