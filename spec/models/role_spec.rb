# frozen_string_literal: true

require "rails_helper"

RSpec.describe Role, type: :model do
  it "is valid with user and name" do
    user = User.create!(
      name: "U",
      email: "role-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    role = user.roles.build(name: "Dev", interest_level: 3)
    expect(role).to be_valid
    expect(role.save).to be true
    expect(role.user_id).to eq(user.id)
  end
end
