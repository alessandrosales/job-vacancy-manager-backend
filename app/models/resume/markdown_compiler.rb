# frozen_string_literal: true

# Generates an ATS-optimised markdown resume from the structured data linked to a Resume record.
# The canonical template used as a reference lives at:
#   app/models/resume/templates/ats_template.md
#
# Usage:
#   resume = Resume::MarkdownCompiler.call(resume: resume)
#   resume.compiled_markdown  # => "# Jane Doe\n\n..."
class Resume::MarkdownCompiler
  class Error < ApiTranslatableError; end

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
    template: no tables, no columns, **plain paragraphs for work experience** (no hyphen or star
    lists under job headings), no icons or emojis.
    Header contact block: plain text only; profile links as full URLs on ONE line, each URL separated from the next by space + middle dot + space (·), never one URL per line; not markdown links. When you output the injected target-role line, precede it with exactly one blank line after the last contact or URL line. No
    markdown links in body sections. The English section titles in the template file are
    illustrative only — you MUST use the exact localized "## …" headings and labels supplied in
    the user message for this request. Omit sections that have no data. Output ONLY the final
    Markdown document — no preamble, no explanation, no code fences. Every visible word (headings,
    month names, "current job" word, remote/on-site labels, target-role label) must be in the output
    language; zero English when the output language is not English.
    Work experience narrative: for each job, after the ### heading and italic dates, write **plain
    paragraph text only** — no `-` list items and no `*` lists for responsibilities. Separate
    paragraphs with a blank line when needed (usually one paragraph; two if the role description is long).
    When SOURCE DATA includes a non-empty Description (or numbered fragments), that content is the
    **only** substantive source — translate and polish into flowing prose while reflecting every numbered
    fragment and major fact (do not omit tools, domains, responsibilities named there). Use title,
    company, dates, arrangement, and skills only to frame. Emphasise or structure sentences toward the
    TARGET ROLE / resume-linked role where the description supports it honestly — never invent facts.
    When Description is not provided, write one concise paragraph from title/company/dates, and
    arrangement only — do not infer tool names for prose.
    **Skills heading rule:** the "## …" skills section (localized title in the user message) must list
    **only** skill names linked via `resume_skills` for this resume — identical to the ordered list in
    SOURCE DATA. Never add skills gleaned from job descriptions, certifications, or elsewhere. You may
    name tools inside work-experience prose when the description mentions them; those names do not belong
    in the skills comma line unless the skill is explicitly in that resume-linked list.
  TEXT

  class << self
    def call(resume:)
      resume_with_associations = load_with_associations(resume)
      model = ENV.fetch("RESUME_MARKDOWN_AI_MODEL", ENV.fetch("RESUME_DESCRIPTION_AI_MODEL", "gpt-4.1-mini"))
      code = Resume.normalize_preferred_language(resume_with_associations.preferred_language)
      lex = OUTPUT_LEXICON.fetch(code, OUTPUT_LEXICON["en"])

      user_message = build_user_message(resume_with_associations)
      system_with_template = "#{SYSTEM_PROMPT}\n\n#{template_reference}"

      chat = User::RubyLlmContext.openai_chat!(user: resume_with_associations.user, model: model)
      response = chat.ask("#{system_with_template}\n\n#{user_message}")
      text = response.content.to_s.strip

      raise Error.new("api.errors.resume.markdown.empty_llm_response") if text.blank?

      text = enforce_skills_section!(text, resume_with_associations, lex)

      resume.update!(compiled_markdown: text)
      resume
    rescue RubyLLM::Error, Faraday::Error => e
      Rails.logger.error("[Resume::MarkdownCompiler] failed: #{e.class}: #{e.message}")
      raise Error.new("api.errors.resume.markdown.generation_failed")
    end

    private

    def load_with_associations(resume)
      Resume
        .includes(
          { user: :reference_links },
          :role,
          { work_experiences: :skills },
          { resume_skills: :skill },
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
      sections << build_work_experience_section(work_exps, lex, code, role: resume.role) if work_exps.any?

      educations = resume.educations.sort_by { |e| [ e.date_to&.to_s || "9999-12-31", e.date_from&.to_s || "9999-12-31" ] }.reverse
      sections << build_education_section(educations, lex, code) if educations.any?

      sections << build_certifications_section(resume.certifications, lex, code) if resume.certifications.any?
      sections << build_skills_section(resume, lex) if ordered_resume_skill_names(resume).any?

      sections.join("\n\n")
    end

    def mandatory_localization_instructions(resume, lex)
      role_name = resume.role&.name.to_s.strip.presence || "(not specified)"
      heading_keys = %i[professional_summary]
      heading_keys << :work_experience if resume.work_experiences.any?
      heading_keys << :education if resume.educations.any?
      heading_keys << :certifications if resume.certifications.any?
      heading_keys << :skills if ordered_resume_skill_names(resume).any?
      heading_lines = heading_keys.map { |k| "## #{lex.fetch(k)}" }.join("\n")

      <<~BLOCK.strip
        MANDATORY — use these EXACT "##" headings in this order for sections that exist in your output
        (copy spelling and accents exactly; omit a heading and its whole section if there is no data):
        #{heading_lines}
        Open-ended dates: when a job or study is still ongoing, end the italic range with "#{lex[:present]}" only — never use the English word Present unless the output language is English.
        Header line for the role linked to this resume (must appear in the contact block): "#{lex[:target_role_prefix]}: #{role_name}"
        Put exactly one blank line between the last header contact/URL line and that target-role line.
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

      urls = links.map(&:url)
      joined = urls.join(" · ")
      lines = [
        "  Reference links — in the OUTPUT header put every URL below on a single line, separated by \" · \", plain https only (no markdown link syntax):",
        "    Required single header line shape: #{joined}"
      ]
      links.each_with_index do |rl, i|
        lines << "    [#{i + 1}] #{rl.title}: #{rl.url}"
      end
      lines.join("\n")
    end

    def build_work_experience_section(work_experiences, lex, code, role:)
      target_role = role&.name.to_s.strip.presence || "(not specified)"
      lines = []
      lines << "WORK EXPERIENCES — for Markdown section \"#{lex[:work_experience]}\""
      lines << <<~ROLECTX.strip
        TARGET ROLE (shape work-experience prose so genuine strengths fit this candidacy; stay factual): #{target_role}
      ROLECTX
      if role&.description.present?
        lines << "TARGET ROLE CONTEXT (alignment hints only—not facts about the candidate; do not quote as employer truth): #{role.description.to_s.strip.truncate(600)}"
      end
      lines << <<~INSTR.squish
        For each job in the final Markdown (section "## #{lex[:work_experience]}"), put the role narrative
        as **paragraphs after the italic date line** — never `-` bullets for duties. If Description or
        numbered fragments appear below for that job, **every** fragment's meaning must appear in that
        prose (you may combine ideas in fluent sentences). Translate to OUTPUT LANGUAGE. If Description
        is "(not provided)", write one tight paragraph from Title, Company, dates, and arrangement only.
        Steer wording toward "#{target_role}" only where facts allow. Never invent metrics or tools.
      INSTR
      lines << "SOURCE DATA (most-recent first):"
      work_experiences.each_with_index do |we, i|
        arrangement = we.is_remote ? lex[:remote] : lex[:on_site]
        lines << "  [#{i + 1}]"
        lines << "    Title: #{we.title.presence || "(untitled)"}"
        lines << "    Company: #{we.company_name.presence || "(unknown company)"}"
        lines << "    From: #{format_date(we.date_from, code)}"
        lines << "    To: #{we.date_to.present? ? format_date(we.date_to, code) : lex[:present]}"
        lines << "    Arrangement (#{lex[:remote]}/#{lex[:on_site]}): #{arrangement}"
        if we.description.present?
          fragments = description_fragments_for_prompt(we.description)
          if fragments.length > 1
            lines << "    Description — PRIMARY (each numbered fragment MUST appear in your paragraph prose for this job):"
            fragments.each_with_index do |fragment, idx|
              lines << "      #{idx + 1}. #{fragment}"
            end
          else
            lines << "    Description (work_experiences.description — PRIMARY for paragraph body below heading): #{we.description}"
          end
        else
          lines << "    Description (work_experiences.description): (not provided — paragraph from Title, Company, dates, arrangement only)"
        end
      end
      lines.join("\n")
    end

    def build_education_section(educations, lex, code)
      lines = [ "EDUCATION (source data; most-recent first — translate content but keep facts):" ]
      lines << "  Output rule: never emit placeholders like (degree)/(field)/(institution)/(unknown)."
      lines << "  Heading composition per education item:"
      lines << "    - Degree + Field -> \"Degree in Field\" (localized connector)"
      lines << "    - only Degree -> \"Degree\""
      lines << "    - only Field -> \"Field\""
      lines << "    - neither Degree nor Field -> omit the `###` education title line"
      educations.each_with_index do |edu, i|
        lines << "  [#{i + 1}]"
        lines << "    Degree: #{edu.degree.presence || "(not provided)"}"
        lines << "    Field: #{edu.field_of_study.presence || "(not provided)"}"
        lines << "    Institution: #{edu.institution_name.presence || "(not provided)"}"
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

    # Skills shown under "## Skills" come only from resume_skills (not work_experience_skills).
    def build_skills_section(resume, lex)
      names = ordered_resume_skill_names(resume)
      return "" if names.empty?

      h = lex[:skills]
      <<~BLOCK.strip
        RESUME-LINKED SKILLS (join resume_skills only) — Markdown section "## #{h}":
        Under that heading, output ONE comma-separated line with EXACTLY these names in this order
        (spell them identically — no synonyms, extras, omissions, dedup reordering):
        #{names.join(", ")}
      BLOCK
    end

    # Order matches resume_skill join rows for stable reproducible Markdown.
    def ordered_resume_skill_names(resume)
      resume.resume_skills.sort_by do |rs|
        t = rs.created_at
        [ t ? t.to_i : 0, rs.skill_id.to_s ]
      end.filter_map do |rs|
        n = rs.skill&.name.to_s.strip
        n.presence
      end
    end

    # Replaces the model's "## Skills" body with the resume_skills whitelist (or removes the section).
    def enforce_skills_section!(markdown, resume, lex)
      names = ordered_resume_skill_names(resume)
      heading = "## #{lex[:skills]}"
      md = markdown.to_s
      # Next block boundary: H2 `## ` (not `###`).
      section_re = /^#{Regexp.escape(heading)}\s*\n.*?(?=^##\s|\z)/m

      if names.empty?
        return md.sub(section_re, "").strip
      end

      body = "#{heading}\n\n#{names.join(", ")}\n\n"
      if md.match?(section_re)
        md.sub(section_re, body)
      else
        "#{md.rstrip}\n\n#{body.strip}\n"
      end
    end

    # Splits stored description into clauses the model must cover in generated prose (full coverage).
    def description_fragments_for_prompt(text)
      raw = text.to_s.strip
      return [] if raw.blank?

      parts = []
      raw.split(/\n{2,}/).each do |block|
        b = block.strip
        next if b.blank?

        b.split(/(?<=[.!?])\s+/).each do |sentence|
          s = sentence.strip
          parts << s if s.present?
        end
      end
      parts = [ raw ] if parts.empty?
      parts
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
