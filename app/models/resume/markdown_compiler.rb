# frozen_string_literal: true

# Generates an ATS-optimised markdown resume from the structured data linked to a Resume record.
# The canonical template used as a reference lives at:
#   app/models/resume/templates/ats_template.md
#
# Usage:
#   resume = Resume::MarkdownCompiler.call(resume: resume)
#   resume.compiled_markdown  # => "# Jane Doe\n\n..."
class Resume::MarkdownCompiler
  class Error < StandardError; end

  TEMPLATE_PATH = Rails.root.join("app/models/resume/templates/ats_template.md").freeze

  LANGUAGE_NAMES = {
    "en"    => "English",
    "pt_br" => "Brazilian Portuguese (pt-BR)",
    "es"    => "Spanish"
  }.freeze

  # Exact strings the model must use for visible Markdown (## headings, date "current" word, etc.).
  OUTPUT_LEXICON = {
    "en" => {
      professional_summary: "Professional Summary",
      work_experience:      "Work Experience",
      education:            "Education",
      certifications:       "Certifications",
      skills:               "Skills",
      present:              "Present",
      remote:               "Remote",
      on_site:              "On-site",
      hybrid:               "Hybrid",
      target_role_prefix:   "Target role"
    },
    "pt_br" => {
      professional_summary: "Resumo profissional",
      work_experience:      "Experiência profissional",
      education:            "Formação acadêmica",
      certifications:       "Certificações",
      skills:               "Habilidades",
      present:              "Atual",
      remote:               "Remoto",
      on_site:              "Presencial",
      hybrid:               "Híbrido",
      target_role_prefix:   "Cargo pretendido"
    },
    "es" => {
      professional_summary: "Resumen profesional",
      work_experience:      "Experiencia profesional",
      education:            "Formación académica",
      certifications:       "Certificaciones",
      skills:               "Habilidades",
      present:              "Actual",
      remote:               "Remoto",
      on_site:              "Presencial",
      hybrid:               "Híbrido",
      target_role_prefix:   "Rol objetivo"
    }
  }.freeze

  # Abbreviated month + year (locale-aware; avoids English %b when language is pt_br/es).
  MONTH_ABBR = {
    "en"    => %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec],
    "pt_br" => %w[jan. fev. mar. abr. mai. jun. jul. ago. set. out. nov. dez.],
    "es"    => %w[ene. feb. mar. abr. may. jun. jul. ago. sep. oct. nov. dic.]
  }.freeze

  SYSTEM_PROMPT = <<~TEXT.squish
    You are a professional resume writer specialised in ATS (Applicant Tracking System) optimisation.
    Your task is to generate a complete, well-structured resume in Markdown format using the
    structured data provided by the user. Always follow the ATS formatting rules from the reference
    template: no tables, no columns, hyphen bullet points for work experience, no icons or emojis.
    Header contact block: plain text only; profile links as full URLs (not markdown links). No
    markdown links in body sections. The English section titles in the template file are
    illustrative only — you MUST use the exact localized "## …" headings and labels supplied in
    the user message for this request. Omit sections that have no data. Output ONLY the final
    Markdown document — no preamble, no explanation, no code fences. Every visible word (headings,
    month names, "current job" word, remote/on-site labels, target-role label) must be in the output
    language; zero English when the output language is not English.
  TEXT

  class << self
    def call(resume:)
      resume_with_associations = load_with_associations(resume)
      model = ENV.fetch("RESUME_MARKDOWN_AI_MODEL", ENV.fetch("RESUME_DESCRIPTION_AI_MODEL", "gpt-4.1-mini"))

      user_message = build_user_message(resume_with_associations)
      system_with_template = "#{SYSTEM_PROMPT}\n\n#{template_reference}"

      chat = RubyLLM.chat(model: model)
      response = chat.ask("#{system_with_template}\n\n#{user_message}")
      text = response.content.to_s.strip

      raise Error, "Empty response from language model." if text.blank?

      resume.update!(compiled_markdown: text)
      resume
    rescue RubyLLM::Error, Faraday::Error => e
      Rails.logger.error("[Resume::MarkdownCompiler] failed: #{e.class}: #{e.message}")
      raise Error, "Could not generate the resume right now."
    end

    private

    def load_with_associations(resume)
      Resume
        .includes(
          { user: :reference_links },
          :role,
          { work_experiences: :skills },
          :certifications,
          :educations,
          :skills
        )
        .find(resume.id)
    end

    def template_reference
      @template_reference ||= File.read(TEMPLATE_PATH)
    rescue Errno::ENOENT
      ""
    end

    def build_user_message(resume)
      code = Resume.normalize_preferred_language(resume.preferred_language)
      lex = OUTPUT_LEXICON.fetch(code, OUTPUT_LEXICON["en"])
      lang = LANGUAGE_NAMES.fetch(code, "English")
      user = resume.user

      sections = []

      sections << <<~HEADER
        OUTPUT LANGUAGE: #{lang}
        Every word in the final Markdown must be in this language — every "##" section title, month
        names, the open-ended date word, remote/on-site labels, and the target-role label. Do not use
        English for any visible text when the output language is not English.
      HEADER

      sections << mandatory_localization_instructions(resume, lex)

      sections << "RESUME TITLE: #{resume.title.presence || "(untitled)"}"
      sections << "RESUME DESCRIPTION (use as professional summary basis): #{resume.description.presence || "(none)"}" if resume.description.present?

      sections << build_user_section(user)

      work_exps = resume.work_experiences.sort_by { |we| [ we.date_to&.to_s || "9999-12-31", we.date_from&.to_s || "9999-12-31" ] }.reverse
      sections << build_work_experience_section(work_exps, lex, code) if work_exps.any?

      educations = resume.educations.sort_by { |e| [ e.date_to&.to_s || "9999-12-31", e.date_from&.to_s || "9999-12-31" ] }.reverse
      sections << build_education_section(educations, lex, code) if educations.any?

      sections << build_certifications_section(resume.certifications, lex, code) if resume.certifications.any?
      sections << build_skills_section(resume.skills) if resume.skills.any?

      sections.join("\n\n")
    end

    def mandatory_localization_instructions(resume, lex)
      role_name = resume.role&.name.to_s.strip.presence || "(not specified)"
      heading_keys = %i[professional_summary]
      heading_keys << :work_experience if resume.work_experiences.any?
      heading_keys << :education if resume.educations.any?
      heading_keys << :certifications if resume.certifications.any?
      heading_keys << :skills if resume.skills.any?
      heading_lines = heading_keys.map { |k| "## #{lex.fetch(k)}" }.join("\n")

      <<~BLOCK.strip
        MANDATORY — use these EXACT "##" headings in this order for sections that exist in your output
        (copy spelling and accents exactly; omit a heading and its whole section if there is no data):
        #{heading_lines}
        Open-ended dates: when a job or study is still ongoing, end the italic range with "#{lex[:present]}" only — never use the English word Present unless the output language is English.
        Header line for the role linked to this resume (must appear in the contact block): "#{lex[:target_role_prefix]}: #{role_name}"
        Work arrangement tag after the company name (pick one): "#{lex[:remote]}", "#{lex[:on_site]}", or "#{lex[:hybrid]}" — never English Remote, On-site, or Hybrid when the output language is not English.
      BLOCK
    end

    def build_user_section(user)
      parts = []
      parts << "CANDIDATE INFORMATION (for header block — use only facts below):"
      parts << "  Name: #{user.name.presence || "(no name)"}"
      parts << "  Email: #{user.email.presence || "(no email)"}"
      parts << "  Phone: #{user.phone.presence || "(not provided)"}"
      parts << "  Age: #{user.age.present? ? user.age.to_s : "(not provided)"}"
      parts << "  Address: #{user.full_address.presence || "(not provided)"}"
      parts << reference_links_block(user)
      parts.join("\n")
    end

    def reference_links_block(user)
      links = user.reference_links.sort_by { |rl| [ rl.title.to_s.downcase, rl.url.to_s ] }
      return "  Reference links: (none)" if links.empty?

      lines = [ "  Reference links (plain full URLs in output header, no markdown link syntax):" ]
      links.each_with_index do |rl, i|
        lines << "    [#{i + 1}] #{rl.title}: #{rl.url}"
      end
      lines.join("\n")
    end

    def build_work_experience_section(work_experiences, lex, code)
      lines = [ "WORK EXPERIENCES (source data; most-recent first — translate content but keep facts):" ]
      work_experiences.each_with_index do |we, i|
        arrangement = we.is_remote ? lex[:remote] : lex[:on_site]
        lines << "  [#{i + 1}]"
        lines << "    Title: #{we.title.presence || "(untitled)"}"
        lines << "    Company: #{we.company_name.presence || "(unknown company)"}"
        lines << "    From: #{format_date(we.date_from, code)}"
        lines << "    To: #{we.date_to.present? ? format_date(we.date_to, code) : lex[:present]}"
        lines << "    Arrangement (#{lex[:remote]}/#{lex[:on_site]}): #{arrangement}"
        skills = we.skills.map(&:name).reject(&:blank?)
        lines << "    Skills used: #{skills.join(", ")}" if skills.any?
      end
      lines.join("\n")
    end

    def build_education_section(educations, lex, code)
      lines = [ "EDUCATION (source data; most-recent first — translate content but keep facts):" ]
      educations.each_with_index do |edu, i|
        lines << "  [#{i + 1}]"
        lines << "    Degree: #{edu.degree.presence || "(degree)"}"
        lines << "    Field: #{edu.field_of_study}" if edu.field_of_study.present?
        lines << "    Institution: #{edu.institution_name.presence || "(institution)"}"
        lines << "    From: #{format_date(edu.date_from, code)}"
        lines << "    To: #{edu.date_to.present? ? format_date(edu.date_to, code) : lex[:present]}"
      end
      lines.join("\n")
    end

    def build_certifications_section(certifications, lex, code)
      lines = [ "CERTIFICATIONS (source data — translate content but keep facts):" ]
      certifications.each_with_index do |cert, i|
        lines << "  [#{i + 1}]"
        lines << "    Name: #{cert.name.presence || "(certification)"}"
        lines << "    From: #{format_date(cert.date_from, code)}" if cert.date_from.present?
        lines << "    To: #{cert.date_to.present? ? format_date(cert.date_to, code) : lex[:present]}" if cert.date_from.present?
      end
      lines.join("\n")
    end

    def build_skills_section(skills)
      names = skills.map { |s| s.name.presence }.compact.reject(&:blank?)
      return "" if names.empty?

      "SKILLS: #{names.join(", ")}"
    end

    def format_date(raw, lang_code)
      return "(unknown)" if raw.blank?

      parsed =
        case raw
        when Date then raw
        else Date.parse(raw.to_s.strip)
        end
      code = Resume.normalize_preferred_language(lang_code)
      months = MONTH_ABBR.fetch(code, MONTH_ABBR["en"])
      "#{months[parsed.month - 1]} #{parsed.year}"
    rescue ArgumentError, TypeError
      raw.to_s
    end
  end
end
