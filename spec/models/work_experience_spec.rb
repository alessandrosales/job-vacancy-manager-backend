# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkExperience, type: :model do
  it "is valid with user, title, company_name, and defaults is_remote" do
    user = User.create!(
      name: "U",
      email: "workexp-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    exp = user.work_experiences.build(title: "Dev", company_name: "Co")
    expect(exp.is_remote).to be false
    expect(exp).to be_valid
    expect(exp.save).to be true
    expect(exp.user_id).to eq(user.id)
  end
end
