# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkExperienceSkill, type: :model do
  it "creates when work experience and skill share the user" do
    user = User.create!(
      name: "U",
      email: "wes-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    skill = user.skills.create!(name: "X")
    we = user.work_experiences.create!(title: "T", company_name: "C", is_remote: false)

    link = described_class.new(
      user_id: user.id,
      work_experience_id: we.id,
      skill_id: skill.id
    )
    expect(link).to be_valid
    expect(link.save).to be true
  end

  it "rejects mismatched owners" do
    alice = User.create!(name: "A", email: "wes-a@example.com", password: "password12", password_confirmation: "password12")
    bob = User.create!(name: "B", email: "wes-b@example.com", password: "password12", password_confirmation: "password12")
    skill = bob.skills.create!(name: "Bob skill")
    we = alice.work_experiences.create!(title: "W", company_name: "C", is_remote: false)

    link = described_class.new(user_id: alice.id, work_experience_id: we.id, skill_id: skill.id)
    expect(link).not_to be_valid
  end
end
