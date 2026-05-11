# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "é válido com atributos obrigatórios" do
    user = User.new(
      name: "Test",
      email: "test@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user).to be_valid
    expect(user.save).to be true
  end

  it "normaliza email em minúsculas" do
    user = User.create!(
      name: "Test",
      email: "  MIXED@Example.COM ",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user.email).to eq("mixed@example.com")
  end

  it "incrementa jwt_version ao rotacionar senha em update" do
    user = User.create!(
      name: "Versão JWT",
      email: "jwt-version@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user.jwt_version).to eq(0)

    user.update!(password: "newpassword12", password_confirmation: "newpassword12")

    expect(user.reload.jwt_version).to eq(1)
  end

  it "invalidate_jwt_sessions! incrementa jwt_version sem mudar senha" do
    user = User.create!(
      name: "Logout",
      email: "logout-all@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect { user.invalidate_jwt_sessions! }.to change { user.reload.jwt_version }.from(0).to(1)
  end
end
