# frozen_string_literal: true

require "rails_helper"

RSpec.describe RegistrationMailer, type: :mailer do
  describe "#welcome" do
    it "uses English by default" do
      user = User.create!(
        name: "New",
        email: "new-en@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "en"
      )
      mail = described_class.with(user: user).welcome
      expect(mail.subject).to eq(I18n.t("registration_mailer.welcome.subject", locale: :en))
      expect(mail.body.raw_source).to include("Thanks for signing up")
    end

    it "uses pt-BR for pt_br users" do
      user = User.create!(
        name: "Novo",
        email: "new-pt@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "pt_br"
      )
      mail = described_class.with(user: user).welcome
      expect(mail.subject).to eq(I18n.t("registration_mailer.welcome.subject", locale: :"pt-BR"))
      expect(mail.body.raw_source).to include("Obrigado por criar")
    end
  end
end
