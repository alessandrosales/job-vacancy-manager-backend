# frozen_string_literal: true

class PasswordMailer < ApplicationMailer
  layout false

  def reset_instructions
    @user = params[:user]
    @token = params[:token]
    mail(to: @user.email, subject: "Reset your password — Job Vacancy Manager")
  end
end
