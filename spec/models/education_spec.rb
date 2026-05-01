# frozen_string_literal: true

require "rails_helper"

RSpec.describe Education, type: :model do
  let(:user) do
    User.create!(
      name: "U",
      email: "edu-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end

  it "is valid with institution_name" do
    edu = user.educations.build(institution_name: "College")
    expect(edu).to be_valid
    expect(edu.save).to be true
    expect(edu.user_id).to eq(user.id)
  end

  it "rejects date_to before date_from" do
    edu = user.educations.build(
      institution_name: "College",
      date_from: Date.new(2022, 1, 1),
      date_to: Date.new(2021, 1, 1)
    )
    expect(edu).not_to be_valid
    expect(edu.errors[:date_to]).to be_present
  end
end
