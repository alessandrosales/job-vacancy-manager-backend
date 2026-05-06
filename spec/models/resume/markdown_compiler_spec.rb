# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resume::MarkdownCompiler do
  describe ".enforce_skills_section! (private)" do
    let(:user) do
      User.create!(
        name: "WE User",
        email: "compiler-skills@example.com",
        password: "password12",
        password_confirmation: "password12"
      )
    end
    let!(:role) { user.roles.create!(name: "Dev", interest_level: 3) }
    let!(:skill_a) { user.skills.create!(name: "RAG", description: "") }
    let!(:skill_b) { user.skills.create!(name: "LLM Engineer", description: "") }

    it "replaces the skills section body with only resume-linked skill names" do
      resume = user.resumes.create!(
        title: "CV",
        description: "Hi",
        role_id: role.id,
        preferred_language: "en"
      )
      resume.sync_skill_links!(user, [ skill_b.id, skill_a.id ])

      reloaded = Resume.includes(resume_skills: :skill).find(resume.id)
      lex = described_class::OUTPUT_LEXICON.fetch("en")

      md = <<~MD
        # Person

        ## Professional Summary

        Text.

        ## Skills

        OpenAI API, RAG, WHMCS modules, extra noise

        ## Education

        Done.
      MD

      fixed = described_class.send(:enforce_skills_section!, md, reloaded, lex)

      canonical = described_class.send(:ordered_resume_skill_names, reloaded).join(", ")
      expect(fixed).to include("## Skills\n\n#{canonical}")
      expect(fixed).not_to include("OpenAI API")
      expect(fixed).not_to include("WHMCS")
    end

    it "removes the skills section when no resume skills are linked" do
      resume = user.resumes.create!(
        title: "Empty skills",
        description: "Hi",
        role_id: role.id,
        preferred_language: "en"
      )
      lex = described_class::OUTPUT_LEXICON.fetch("en")

      md = "## Skills\n\nPhantom, List\n\n## Education\n\nX"
      fixed = described_class.send(:enforce_skills_section!, md, resume, lex)

      expect(fixed).not_to include("## Skills")
      expect(fixed).not_to include("Phantom")
    end
  end
end
