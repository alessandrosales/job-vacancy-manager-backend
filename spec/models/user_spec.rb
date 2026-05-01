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
end
