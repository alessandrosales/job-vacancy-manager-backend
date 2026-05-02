# frozen_string_literal: true

class PasswordMailer < ApplicationMailer
  layout false

  def reset_instructions
    @user = params[:user]
    @reset_link = FrontendUrl.password_reset_link(params[:token])
    mail(to: @user.email, subject: "Reset your password — Job Vacancy Manager")
  end

  def password_changed
    @user = params[:user]
    mail(to: @user.email, subject: "Your password was changed — Job Vacancy Manager")
  end
end
