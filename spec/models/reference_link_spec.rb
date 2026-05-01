# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceLink, type: :model do
  it "is valid with user, title, and url" do
    user = User.create!(
      name: "U",
      email: "reflink-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    link = user.reference_links.build(title: "T", url: "https://x.com")
    expect(link).to be_valid
    expect(link.save).to be true
    expect(link.user_id).to eq(user.id)
  end
end
