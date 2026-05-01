# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certification, type: :model do
  let(:user) do
    User.create!(
      name: "U",
      email: "cert-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end

  it "is valid with user and name" do
    cert = user.certifications.build(name: "CPA")
    expect(cert).to be_valid
    expect(cert.save).to be true
    expect(cert.user_id).to eq(user.id)
  end

  it "rejects date_to before date_from" do
    cert = user.certifications.build(
      name: "X",
      date_from: Date.new(2022, 1, 1),
      date_to: Date.new(2021, 1, 1)
    )
    expect(cert).not_to be_valid
    expect(cert.errors[:date_to]).to be_present
  end
end
