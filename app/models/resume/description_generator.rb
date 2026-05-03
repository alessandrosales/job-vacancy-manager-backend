# frozen_string_literal: true

# Generates a professional resume description from structured context (title, role, linked
# records) using RubyLLM. Invoked by the API for the "Generate with AI" flow on the resume form.
class Resume::DescriptionGenerator
  class Error < StandardError; end

  SYSTEM = <<~TEXT.squish
    You help polish resume profile descriptions for a job search tracker.
    When the user provides a "Current description" draft, your primary job is to revise and improve
    THAT text: keep its facts, employers, technologies, and achievements; improve clarity, flow,
    grammar, and professional tone. Do not replace it with a generic unrelated biography.
    When no draft is provided, compose a concise summary from the structured facts only.
    Output plain prose only: no markdown headings, no numbered lists unless a short inline list
    is natural inside one paragraph. Prefer first person or neutral professional voice.
    Aim for roughly 3–8 sentences unless the draft clearly needs more.
  TEXT

  class << self
    def call(title:, role_name: nil, work_experience_summaries: [], certification_names: [],
      education_summaries: [], skill_names: [], previous_description: "")
      model = ENV.fetch(
        "RESUME_DESCRIPTION_AI_MODEL",
        ENV.fetch("RESUME_IMPORT_OPENAI_MODEL", "gpt-4.1-mini")
      )
      user_message = build_user_message(
        title: title.to_s,
        role_name: role_name,
        work_experience_summaries: Array(work_experience_summaries).map(&:to_s).reject(&:blank?),
        certification_names: Array(certification_names).map(&:to_s).reject(&:blank?),
        education_summaries: Array(education_summaries).map(&:to_s).reject(&:blank?),
        skill_names: Array(skill_names).map(&:to_s).reject(&:blank?),
        previous_description: previous_description.to_s
      )

      chat = RubyLLM.chat(model: model)
      response = chat.ask("#{SYSTEM}\n\n#{user_message}")
      text = response.content.to_s.strip
      raise Error, "Empty response from language model." if text.blank?

      text
    rescue RubyLLM::Error, Faraday::Error => e
      Rails.logger.error("[Resume::DescriptionGenerator] failed: #{e.class}: #{e.message}")
      raise Error, "Could not generate a description right now."
    end

    private

    def build_user_message(title:, role_name:, work_experience_summaries:, certification_names:,
      education_summaries:, skill_names:, previous_description:)
      draft = previous_description.strip
      if draft.present?
        build_revision_message(
          draft: draft,
          title: title,
          role_name: role_name,
          work_experience_summaries: work_experience_summaries,
          certification_names: certification_names,
          education_summaries: education_summaries,
          skill_names: skill_names
        )
      else
        build_compose_message(
          title: title,
          role_name: role_name,
          work_experience_summaries: work_experience_summaries,
          certification_names: certification_names,
          education_summaries: education_summaries,
          skill_names: skill_names
        )
      end
    end

    def build_revision_message(draft:, title:, role_name:, work_experience_summaries:,
      certification_names:, education_summaries:, skill_names:)
      sections = []
      sections << <<~HEAD.squish
        The user wrote the description below in the app. Return a single improved version of THIS
        text as the full resume description. Lead with their content; you may reorganize sentences
        and sharpen language. If supporting facts below add missing detail that clearly fits the
        same profile, you may weave them in briefly—never invent employers, dates, or credentials.
      HEAD
      sections << "Current description (revise this):\n\n#{draft}"
      sections << "Resume title (alignment): #{title.strip.presence || "(untitled)"}"
      sections << "Target role / focus: #{role_name.to_s.strip}" if role_name.present?
      ctx = supporting_context_block(
        work_experience_summaries: work_experience_summaries,
        certification_names: certification_names,
        education_summaries: education_summaries,
        skill_names: skill_names
      )
      sections << ctx if ctx.present?
      sections.join("\n\n")
    end

    def build_compose_message(title:, role_name:, work_experience_summaries:, certification_names:,
      education_summaries:, skill_names:)
      parts = []
      parts << "No draft was provided. Write a single cohesive professional summary from these facts."
      parts << "Resume title: #{title.strip.presence || "(untitled)"}"
      parts << "Target role / focus: #{role_name.to_s.strip}" if role_name.present?
      ctx = supporting_context_block(
        work_experience_summaries: work_experience_summaries,
        certification_names: certification_names,
        education_summaries: education_summaries,
        skill_names: skill_names
      )
      parts << ctx if ctx.present?
      parts.join("\n\n")
    end

    def supporting_context_block(work_experience_summaries:, certification_names:, education_summaries:,
      skill_names:)
      lines = []
      if work_experience_summaries.any?
        lines << "Work experiences linked to this resume:\n#{work_experience_summaries.join("\n")}"
      end
      lines << "Certifications: #{certification_names.join(", ")}" if certification_names.any?
      lines << "Education: #{education_summaries.join(" | ")}" if education_summaries.any?
      lines << "Skills: #{skill_names.join(", ")}" if skill_names.any?
      return "" if lines.empty?

      "Supporting context (optional; do not contradict a provided draft):\n#{lines.join("\n")}"
    end
  end
end
