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
          "skills" => [
            { "name" => "Go", "description" => "API services" },
            { "name" => "Docker", "description" => "" }
          ],
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
          "skills" => [
            { "name" => "Ruby", "description" => "from role" }
          ],
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
        .and change(Skill, :count).by(3)
        .and change(Role, :count).by(1)
        .and change(Language, :count).by(2)
        .and change(Company, :count).by(1)
        .and change(ReferenceLink, :count).by(2)

      resume = user.resumes.order(:created_at).last
      expect(resume.title).to eq("Backend Developer")
      expect(resume.description).to eq("Summary line")
      expect(resume.role_id).to eq(role.id)
      expect(resume.preferred_language).to eq("en")
      expect(resume.work_experience_ids.size).to eq(2)
      expect(resume.education_ids.size).to eq(1)
      expect(resume.certification_ids.size).to eq(1)
      expect(resume.skill_ids.size).to eq(3)
      expect(user.skills.order(:name).pluck(:name)).to eq([ "Docker", "Go", "Ruby" ])

      dev_we, lead_we = user.work_experiences.order(date_from: :desc).to_a
      expect(dev_we.title).to eq("Developer")
      expect(dev_we.description).to eq("B2B SaaS\n\nBuilt APIs and mentored juniors.")
      expect(lead_we.description).to eq("Owned CI/CD migration.")
      expect(dev_we.skill_ids.size).to eq(2)
      expect(lead_we.skill_ids).to eq([ user.skills.find_by!("name" => "Ruby").id ])
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

    it "stores preferred_language when provided" do
      described_class.call(
        user: user,
        role_id: role.id,
        extracted_payload: payload,
        preferred_language: "pt_br"
      )
      expect(user.resumes.order(:created_at).last.preferred_language).to eq("pt_br")
    end

    it "stores one work_experience description when company_description and description are the same" do
      narrative = "Developed the Listados project aimed at expanding the portfolio."
      payload_dup = empty_child_payload.merge(
        "work_experiences" => [
          {
            "title" => "Web Developer",
            "company_name" => "Dedupe Desc Co",
            "company_url" => "",
            "company_description" => narrative,
            "description" => narrative,
            "skills" => [],
            "is_remote" => false,
            "date_from" => "2022-01-01",
            "date_to" => ""
          }
        ]
      )
      described_class.call(user: user, role_id: role.id, extracted_payload: payload_dup)
      we = user.work_experiences.find_by!(company_name: "Dedupe Desc Co")
      expect(we.description).to eq(narrative)
    end

    it "drops consecutive duplicate paragraphs pasted only in the role description field" do
      para = "Responsible for implementation and evolution of the platform."
      doubled = "#{para}\n\n#{para}"
      payload_para = empty_child_payload.merge(
        "work_experiences" => [
          {
            "title" => "Engineer",
            "company_name" => "ParaDedup Inc",
            "company_url" => "",
            "company_description" => "",
            "description" => doubled,
            "skills" => [],
            "is_remote" => true,
            "date_from" => "2021-06-01",
            "date_to" => "2022-01-01"
          }
        ]
      )
      described_class.call(user: user, role_id: role.id, extracted_payload: payload_para)
      we = user.work_experiences.find_by!(company_name: "ParaDedup Inc")
      expect(we.description).to eq(para)
    end

    let(:empty_child_payload) do
      {
        "resume" => { "title" => "Dedupe test" },
        "work_experiences" => [],
        "educations" => [],
        "certifications" => [],
        "skills" => [],
        "roles" => [],
        "languages" => [],
        "reference_links" => []
      }
    end

    it "deduplicates certifications repeated in the same payload (case, nil dates, odd spaces)" do
      dup_cert_payload = empty_child_payload.merge(
        "certifications" => [
          { "name" => "Gestão Ágil de Projetos", "date_from" => "", "date_to" => "" },
          { "name" => "GESTÃO ÁGIL DE PROJETOS", "date_from" => nil, "date_to" => nil },
          { "name" => "Gestão \u00A0 Ágil  de  Projetos", "date_from" => "", "date_to" => "" }
        ]
      )
      expect do
        described_class.call(user: user, role_id: role.id, extracted_payload: dup_cert_payload)
      end.to change(Certification, :count).by(1)

      resume = user.resumes.order(:created_at).last
      expect(resume.certification_ids.uniq.size).to eq(1)
    end

    it "deduplicates educations in the same payload when field_of_study differs only by case" do
      dup_edu_payload = empty_child_payload.merge(
        "educations" => [
          {
            "institution_name" => "Faculdade de Tecnologia do Nordeste",
            "degree" => "",
            "field_of_study" => "Análise de Desenvolvimento de Sistemas",
            "date_from" => "2007-01-01",
            "date_to" => ""
          },
          {
            "institution_name" => "faculdade de tecnologia do nordeste",
            "degree" => nil,
            "field_of_study" => "análise de desenvolvimento de sistemas",
            "date_from" => "2007-01-01",
            "date_to" => ""
          }
        ]
      )
      expect do
        described_class.call(user: user, role_id: role.id, extracted_payload: dup_edu_payload)
      end.to change(Education, :count).by(1)

      resume = user.resumes.order(:created_at).last
      expect(resume.education_ids.uniq.size).to eq(1)
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
