# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "é válido com atributos obrigatórios" do
    user = User.new(
      name: "Test",
      email: "test@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user).to be_valid
    expect(user.save).to be true
  end

  it "normaliza email em minúsculas" do
    user = User.create!(
      name: "Test",
      email: "  MIXED@Example.COM ",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user.email).to eq("mixed@example.com")
  end

  it "incrementa jwt_version ao rotacionar senha em update" do
    user = User.create!(
      name: "Versão JWT",
      email: "jwt-version@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect(user.jwt_version).to eq(0)

    user.update!(password: "newpassword12", password_confirmation: "newpassword12")

    expect(user.reload.jwt_version).to eq(1)
  end

  it "invalidate_jwt_sessions! incrementa jwt_version sem mudar senha" do
    user = User.create!(
      name: "Logout",
      email: "logout-all@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
    expect { user.invalidate_jwt_sessions! }.to change { user.reload.jwt_version }.from(0).to(1)
  end

  describe ".find_or_create_from_firebase!" do
    let(:claims) do
      {
        "sub" => "firebase-spec-uid",
        "email" => "firebase-model-spec@example.com",
        "name" => "Firebase Model"
      }
    end

    it "envia e-mail de boas-vindas na primeira criação" do
      ActionMailer::Base.deliveries.clear
      described_class.find_or_create_from_firebase!(claims)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "firebase-model-spec@example.com" ])
      expect(mail.subject).to eq(I18n.t("registration_mailer.welcome.subject", locale: :en))
    end

    it "não envia e-mail em logins subsequentes do mesmo usuário Firebase" do
      described_class.find_or_create_from_firebase!(claims)
      ActionMailer::Base.deliveries.clear
      described_class.find_or_create_from_firebase!(claims)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "não envia e-mail ao vincular Firebase a conta já existente por e-mail" do
      User.create!(
        name: "Já existia",
        email: "firebase-link@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      ActionMailer::Base.deliveries.clear
      described_class.find_or_create_from_firebase!({
        "sub" => "novo-firebase-uid",
        "email" => "firebase-link@example.com",
        "name" => "Nome Token"
      })
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(User.find_by!(email: "firebase-link@example.com").firebase_uid).to eq("novo-firebase-uid")
    end

    it "persiste o preferred_language recebido em novas contas" do
      user = described_class.find_or_create_from_firebase!(claims, preferred_language: "pt_br")
      expect(user.preferred_language).to eq("pt_br")
    end

    it "ignora preferred_language inválido em novas contas e mantém o default 'en'" do
      user = described_class.find_or_create_from_firebase!(claims, preferred_language: "fr")
      expect(user.preferred_language).to eq("en")
    end

    it "não sobrescreve preferred_language existente em logins subsequentes" do
      existing = described_class.find_or_create_from_firebase!(claims, preferred_language: "pt_br")
      described_class.find_or_create_from_firebase!(claims, preferred_language: "es")
      expect(existing.reload.preferred_language).to eq("pt_br")
    end

    it "não sobrescreve preferred_language ao vincular Firebase a conta já existente por e-mail" do
      User.create!(
        name: "Existente PT",
        email: "firebase-pref-link@example.com",
        password: "password12",
        password_confirmation: "password12",
        preferred_language: "pt_br"
      )
      described_class.find_or_create_from_firebase!(
        {
          "sub" => "firebase-pref-uid",
          "email" => "firebase-pref-link@example.com",
          "name" => "Existente PT"
        },
        preferred_language: "es"
      )
      expect(User.find_by!(email: "firebase-pref-link@example.com").preferred_language).to eq("pt_br")
    end
  end
end
