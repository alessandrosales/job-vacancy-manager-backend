# frozen_string_literal: true

require "rails_helper"

RSpec.describe FrontendUrl do
  describe ".password_reset_link" do
    it "builds a URL with reset_token query param from FRONTEND_URL" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FRONTEND_URL").and_return("https://app.example.com")

      link = described_class.password_reset_link("tok123")
      uri = URI.parse(link)
      expect(uri.scheme).to eq("https")
      expect(uri.host).to eq("app.example.com")
      expect(uri.path).to eq("/reset-password")
      expect(URI.decode_www_form(uri.query.to_s).to_h["reset_token"]).to eq("tok123")
    end

    it "raises in production when frontend URL is not configured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FRONTEND_URL").and_return(nil)
      allow(Rails.env).to receive(:production?).and_return(true)

      expect {
        described_class.password_reset_link("x")
      }.to raise_error(FrontendUrl::MissingFrontendUrlError)
    end
  end
end
