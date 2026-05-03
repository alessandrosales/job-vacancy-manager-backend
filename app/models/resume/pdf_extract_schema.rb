# frozen_string_literal: true

# JSON Schema for RubyLLM / OpenAI structured output. Strict response_format requires
# every property of an object to appear in `required` (optional fields use empty string
# or sensible defaults—see EXTRACTION_PROMPT in PdfImporter).
class Resume::PdfExtractSchema < RubyLLM::Schema
  description "Structured resume fields extracted only from the attached CV PDF"

  object :resume, description: "Top-level resume metadata" do
    string :title, description: "Headline, desired role, or document title as shown on the CV"
    string :description,
      description: "Professional summary or profile paragraph; use empty string if absent on the CV"
  end

  array :work_experiences, description: "Employment history (most recent first if obvious); use [] if none" do
    object do
      string :title, description: "Job title"
      string :company_name, description: "Employer or organization name"
      string :company_url,
        description: "Employer website URL if printed on the CV; empty string if none"
      string :company_description,
        description: "Short one-line about the employer or division if shown on the CV; empty string if none"
      string :description,
        description: "Responsibilities, scope, and achievements for this role (bullets or paragraph as on the CV); empty string if none"
      boolean :is_remote,
        description: "True only if explicitly remote or home office; false otherwise or if unclear"
      string :date_from, description: "Start date as ISO YYYY-MM-DD; use empty string if unknown"
      string :date_to,
        description: "End date as ISO YYYY-MM-DD; use empty string if unknown or current role"
    end
  end

  array :educations, description: "Formal education entries; use [] if none" do
    object do
      string :institution_name, description: "School or university name"
      string :degree, description: "Degree or certification level (e.g. Bachelor, MBA); empty if unknown"
      string :field_of_study, description: "Major or concentration; empty if unknown"
      string :date_from, description: "Start as ISO YYYY-MM-DD or empty string"
      string :date_to, description: "End as ISO YYYY-MM-DD or empty string"
    end
  end

  array :certifications, description: "Professional certifications or licenses; use [] if none" do
    object do
      string :name, description: "Certification or license name"
      string :date_from, description: "Issue or valid-from as ISO YYYY-MM-DD or empty string"
      string :date_to, description: "Expiry as ISO YYYY-MM-DD or empty string if none"
    end
  end

  array :skills, description: "Distinct technical or professional skills (deduplicated); use [] if none" do
    object do
      string :name, description: "Skill name"
      string :description, description: "Optional short context (years, level); empty string if none"
    end
  end

  array :roles,
    description: "Professional titles or target roles explicitly listed on the CV (headline, summary, objective); deduplicated by name; use [] if none" do
    object do
      string :name, description: "Role or job title label as on the CV"
      string :description,
        description: "Optional one-line context from the CV; empty string if none"
    end
  end

  array :languages,
    description: "Spoken or written languages with proficiency from the CV; use [] if none" do
    object do
      string :name, description: "Language name (e.g. English, Portuguese)"
      string :level,
        enum: Language::LEVELS,
        description: "Map document wording to exactly one of: beginner, intermediate, advanced, native"
    end
  end

  array :reference_links,
    description: "Profile and portfolio URLs (LinkedIn, GitHub, personal site, etc.); dedupe by URL; use [] if none" do
    object do
      string :title,
        description: "Short label (e.g. LinkedIn, GitHub); empty string if obvious from the URL host"
      string :url, description: "Full URL including scheme (https://...)"
    end
  end
end
