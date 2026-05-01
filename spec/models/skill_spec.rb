# frozen_string_literal: true

require "rails_helper"

RSpec.describe Skill, type: :model do
  it "is valid with user and name" do
    user = User.create!(
      name: "U",
      email: "skill-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    skill = user.skills.build(name: "SQL")
    expect(skill).to be_valid
    expect(skill.save).to be true
    expect(skill.user_id).to eq(user.id)
  end
end
