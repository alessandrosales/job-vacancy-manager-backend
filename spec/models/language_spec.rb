# frozen_string_literal: true

require "rails_helper"

RSpec.describe Language do
  let(:user) do
    User.create!(
      name: "L",
      email: "lang-model@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end

  it "is valid with name and allowed level" do
    lang = user.languages.build(name: "French", level: "intermediate")
    expect(lang).to be_valid
  end

  it "rejects unknown level" do
    lang = user.languages.build(name: "X", level: "fluent")
    expect(lang).not_to be_valid
    expect(lang.errors[:level]).to be_present
  end
end
