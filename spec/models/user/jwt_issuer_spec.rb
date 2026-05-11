# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::JwtIssuer do
  describe ".encode / .user_from_token" do
    it "round-trips with jwt_version claim" do
      user = User.create!(
        name: "JWT User",
        email: "jwt-user@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      token = described_class.encode(user)
      decoded = JWT.decode(token, described_class.send(:secret), true, { algorithm: "HS256" }).first
      expect(decoded).to include("sub" => user.id, "jv" => user.jwt_version)

      expect(described_class.user_from_token(token)).to eq(user)
    end

    it "accepts legacy tokens without jv only while jwt_version is still 0" do
      user = User.create!(
        name: "Legacy",
        email: "legacy-jwt@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      payload = { "sub" => user.id, "exp" => 1.hour.from_now.to_i }
      token = JWT.encode(payload, described_class.send(:secret), "HS256", { typ: "JWT" })

      expect(described_class.user_from_token(token)).to eq(user)

      user.update!(password: "newpassword12", password_confirmation: "newpassword12")

      expect(described_class.user_from_token(token)).to be_nil
    end

    it "rejects tokens when jwt_version no longer matches (password rotation)" do
      user = User.create!(
        name: "Rotate",
        email: "rotate-jwt@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      token = described_class.encode(user)

      user.update!(password: "newpassword12", password_confirmation: "newpassword12")

      expect(described_class.user_from_token(token)).to be_nil
      expect(described_class.user_from_token(described_class.encode(user))).to eq(user.reload)
    end
  end
end
