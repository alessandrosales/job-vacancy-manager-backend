# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resume, type: :model do
  let(:user) do
    User.create!(
      name: "U",
      email: "resume-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let(:role) { user.roles.create!(name: "Dev", interest_level: 3) }

  it "is valid with title and role for user" do
    resume = user.resumes.build(title: "CV", role: role)
    expect(resume).to be_valid
    expect(resume.save).to be true
  end

  it "rejects role_id from another user" do
    other = User.create!(
      name: "O",
      email: "other-resume@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    foreign_role = other.roles.create!(name: "Other", interest_level: 1)

    resume = user.resumes.build(title: "Bad", role_id: foreign_role.id)
    expect(resume).not_to be_valid
    expect(resume.errors[:role_id]).to be_present
  end
end
