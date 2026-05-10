# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasswordMailer, type: :mailer do
  describe "#reset_instructions" do
    let(:token) { "reset-token-xyz" }

    it "uses English when preferred_language is en" do
      user = User.create!(
        name: "Alex",
        email: "alex-en@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "en"
      )
      mail = described_class.with(user: user, token: token).reset_instructions
      expect(mail.subject).to eq(I18n.t("password_mailer.reset_instructions.subject", locale: :en))
      expect(mail.body.raw_source).to include("We received a request")
    end

    it "uses pt-BR when preferred_language is pt_br" do
      user = User.create!(
        name: "Alex",
        email: "alex-pt@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "pt_br"
      )
      mail = described_class.with(user: user, token: token).reset_instructions
      expect(mail.subject).to eq(I18n.t("password_mailer.reset_instructions.subject", locale: :"pt-BR"))
      expect(mail.body.raw_source).to include("Recebemos um pedido")
    end

    it "uses Spanish when preferred_language is es" do
      user = User.create!(
        name: "Alex",
        email: "alex-es@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "es"
      )
      mail = described_class.with(user: user, token: token).reset_instructions
      expect(mail.subject).to eq(I18n.t("password_mailer.reset_instructions.subject", locale: :es))
      expect(mail.body.raw_source).to include("Recibimos una solicitud")
    end
  end

  describe "#password_changed" do
    it "uses pt-BR copy for pt_br users" do
      user = User.create!(
        name: "Pat",
        email: "pat-pt@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "pt_br"
      )
      mail = described_class.with(user: user).password_changed
      expect(mail.subject).to eq(I18n.t("password_mailer.password_changed.subject", locale: :"pt-BR"))
      expect(mail.body.raw_source).to include("Esta é uma confirmação")
    end
  end
end
