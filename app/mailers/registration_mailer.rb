# frozen_string_literal: true

class RegistrationMailer < ApplicationMailer
  layout false

  def welcome
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome to Hireest")
  end
end
