# frozen_string_literal: true

# Generates a professional resume description from structured context (title, role, linked
# records) using RubyLLM. Invoked by the API for the "Generate with AI" flow on the resume form.
class Resume::DescriptionGenerator
  class Error < StandardError; end

  SYSTEM = <<~TEXT.squish
    You improve resume profile descriptions for a job search tracker.
    LANGUAGE: The user message states a required output language. Write the entire answer in that
    language only—never mix languages.
    CURRENT TEXT FIRST: When a "Current description" draft is present, it is the primary source of truth.
    Preserve the candidate's facts, employers, technologies, timelines, and achievements; improve clarity,
    flow, grammar, and professional tone. Do not replace substantive content with a generic unrelated biography.
    TARGET ROLE: When a target role is named, align emphasis and framing so the summary supports candidacy for
    that role, using only evidence consistent with the inputs—never invent employers, dates, or credentials.
    QUALITY: Sound credible to a hiring manager and typical ATS screening: concrete, specific, outcome-oriented
    where the material allows; avoid empty buzzwords, hype, or unsupported superlatives.
    WHEN NO DRAFT: Compose a concise summary only from the structured facts—still in the required language.
    FORMAT: Plain prose only—no markdown headings, no bullet lists unless a short inline list is natural in one paragraph.
    LENGTH: About 3–8 sentences unless the draft clearly needs more.
  TEXT

  class << self
    def call(title:, role_name: nil, work_experience_summaries: [], certification_names: [],
      education_summaries: [], skill_names: [], previous_description: "", preferred_language: nil)
      model = ENV.fetch(
        "RESUME_DESCRIPTION_AI_MODEL",
        ENV.fetch("RESUME_IMPORT_OPENAI_MODEL", "gpt-4.1-mini")
      )
      lang = Resume.normalize_preferred_language(preferred_language)
      user_message = build_user_message(
        title: title.to_s,
        role_name: role_name,
        work_experience_summaries: Array(work_experience_summaries).map(&:to_s).reject(&:blank?),
        certification_names: Array(certification_names).map(&:to_s).reject(&:blank?),
        education_summaries: Array(education_summaries).map(&:to_s).reject(&:blank?),
        skill_names: Array(skill_names).map(&:to_s).reject(&:blank?),
        previous_description: previous_description.to_s,
        preferred_language: lang
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
      education_summaries:, skill_names:, previous_description:, preferred_language:)
      draft = previous_description.strip
      if draft.present?
        build_revision_message(
          draft: draft,
          title: title,
          role_name: role_name,
          work_experience_summaries: work_experience_summaries,
          certification_names: certification_names,
          education_summaries: education_summaries,
          skill_names: skill_names,
          preferred_language: preferred_language
        )
      else
        build_compose_message(
          title: title,
          role_name: role_name,
          work_experience_summaries: work_experience_summaries,
          certification_names: certification_names,
          education_summaries: education_summaries,
          skill_names: skill_names,
          preferred_language: preferred_language
        )
      end
    end

    def build_revision_message(draft:, title:, role_name:, work_experience_summaries:,
      certification_names:, education_summaries:, skill_names:, preferred_language:)
      sections = []
      sections << output_language_clause(preferred_language)
      sections << <<~HEAD.squish
        The user wrote the description below in the app. Return a single improved version of THIS
        text as the full resume description. Treat the draft as mandatory raw material: keep its facts,
        employers, technologies, timelines, and achievements; you may reorganize sentences and sharpen
        language for a stronger professional impression. If supporting facts below add missing detail that
        clearly fits the same profile, weave them in briefly—never invent employers, dates, or credentials.
      HEAD
      sections << "Current description (revise this):\n\n#{draft}"
      sections << "Resume title (alignment): #{title.strip.presence || "(untitled)"}"
      if role_name.present?
        sections << <<~ROLE.squish
          Target role linked to this resume: #{role_name.to_s.strip}. Shape the narrative so a reader
          immediately sees relevance for this role, without adding claims not supported above.
        ROLE
      end
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
      education_summaries:, skill_names:, preferred_language:)
      parts = []
      parts << output_language_clause(preferred_language)
      parts << "No draft was provided. Write a single cohesive professional summary from these facts."
      parts << "Resume title: #{title.strip.presence || "(untitled)"}"
      if role_name.present?
        parts << <<~ROLE.squish
          Target role linked to this resume: #{role_name.to_s.strip}. Emphasize strengths and experience
          that support this role; do not invent credentials.
        ROLE
      end
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

    def output_language_clause(code)
      name = output_language_name(code)
      <<~LANG.squish
        OUTPUT LANGUAGE (mandatory): #{name}. Write the entire resume description in #{name} only.
        The resume form language setting is #{code}; match that locale in vocabulary and conventions.
      LANG
    end

    def output_language_name(code)
      case code
      when "pt_br"
        "Portuguese (Brazil)"
      when "es"
        "Spanish"
      else
        "English"
      end
    end
  end
end
