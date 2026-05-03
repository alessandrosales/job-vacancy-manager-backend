# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resume::PdfImporter do
  let(:user) do
    User.create!(
      name: "Import User",
      email: "pdf-import-user@example.com",
      password: "password12",
      password_confirmation: "password12"
    )
  end
  let!(:role) { user.roles.create!(name: "Engineer", interest_level: 3) }

  let(:payload) do
    {
      "resume" => { "title" => "Backend Developer", "description" => "Summary line" },
      "work_experiences" => [
        {
          "title" => "Developer",
          "company_name" => "Acme",
          "company_url" => "https://acme.example",
          "company_description" => "B2B SaaS",
          "description" => "Built APIs and mentored juniors.",
          "is_remote" => true,
          "date_from" => "2020-01-01",
          "date_to" => ""
        },
        {
          "title" => "Lead",
          "company_name" => "acme",
          "company_url" => "",
          "company_description" => "",
          "description" => "Owned CI/CD migration.",
          "is_remote" => false,
          "date_from" => "2018-01-01",
          "date_to" => "2019-12-31"
        }
      ],
      "educations" => [
        {
          "institution_name" => "State University",
          "degree" => "BSc",
          "field_of_study" => "CS",
          "date_from" => "2012-09-01",
          "date_to" => "2016-06-01"
        }
      ],
      "certifications" => [
        { "name" => "AWS SA", "date_from" => "2021-03-01", "date_to" => "" }
      ],
      "skills" => [
        { "name" => "Ruby", "description" => "" },
        { "name" => "ruby", "description" => nil }
      ],
      "roles" => [
        { "name" => "Staff Engineer", "description" => "From summary" },
        { "name" => "engineer", "description" => "" }
      ],
      "languages" => [
        { "name" => "English", "level" => "native" },
        { "name" => "Spanish", "level" => "beginner" }
      ],
      "reference_links" => [
        { "title" => "GitHub", "url" => "https://github.com/jane" },
        { "title" => "", "url" => "https://www.linkedin.com/in/jane" },
        { "title" => "GitHub", "url" => "https://github.com/jane" }
      ]
    }
  end

  describe ".call with extracted_payload" do
    it "creates resume, child records, and join rows" do
      expect do
        described_class.call(user: user, role_id: role.id, extracted_payload: payload)
      end.to change(Resume, :count).by(1)
        .and change(WorkExperience, :count).by(2)
        .and change(Education, :count).by(1)
        .and change(Certification, :count).by(1)
        .and change(Skill, :count).by(1)
        .and change(Role, :count).by(1)
        .and change(Language, :count).by(2)
        .and change(Company, :count).by(1)
        .and change(ReferenceLink, :count).by(2)

      resume = user.resumes.order(:created_at).last
      expect(resume.title).to eq("Backend Developer")
      expect(resume.description).to eq("Summary line")
      expect(resume.role_id).to eq(role.id)
      expect(resume.work_experience_ids.size).to eq(2)
      expect(resume.education_ids.size).to eq(1)
      expect(resume.certification_ids.size).to eq(1)
      expect(resume.skill_ids.size).to eq(1)
      expect(user.skills.pluck(:name)).to eq([ "Ruby" ])
      expect(user.roles.order(:created_at).last.name).to eq("Staff Engineer")
      expect(user.languages.order(:name).pluck(:name, :level)).to contain_exactly(
        [ "English", "native" ],
        [ "Spanish", "beginner" ]
      )
      acme = user.companies.sole
      expect(acme.name).to eq("Acme")
      expect(acme.url).to eq("https://acme.example")
      expect(acme.description).to include("B2B SaaS")
      expect(acme.description).to include("Built APIs and mentored juniors.")
      expect(acme.description).to include("Owned CI/CD migration.")
      expect(acme.description).to include("---")

      links = user.reference_links.order(:url).to_a
      expect(links.map(&:url)).to contain_exactly(
        "https://github.com/jane",
        "https://www.linkedin.com/in/jane"
      )
      expect(links.find { |l| l.url.include?("linkedin") }.title).to eq("LinkedIn")
    end

    it "does not duplicate user data when importing the same payload again" do
      described_class.call(user: user, role_id: role.id, extracted_payload: payload)

      expect do
        described_class.call(user: user, role_id: role.id, extracted_payload: payload)
      end.to change(Resume, :count).by(1)
        .and change(WorkExperience, :count).by(0)
        .and change(Education, :count).by(0)
        .and change(Certification, :count).by(0)
        .and change(Skill, :count).by(0)
        .and change(Role, :count).by(0)
        .and change(Language, :count).by(0)
        .and change(Company, :count).by(0)
        .and change(ReferenceLink, :count).by(0)
    end

    it "raises when role_id is not owned by user" do
      other = User.create!(
        name: "Other",
        email: "other-pdf@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
      foreign_role = other.roles.create!(name: "X", interest_level: 1)

      expect do
        described_class.call(user: user, role_id: foreign_role.id, extracted_payload: payload)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
