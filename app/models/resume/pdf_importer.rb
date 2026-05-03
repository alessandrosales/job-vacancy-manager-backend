# frozen_string_literal: true

class Resume::PdfImporter
  class Error < StandardError; end

  EXTRACTION_PROMPT = <<~PROMPT.squish
    You are parsing a job resume PDF. Extract only information explicitly present in the document.
    Use ISO date format YYYY-MM-DD for all dates; use empty strings for unknown dates.
    For booleans, infer is_remote only when the document clearly states remote, home office, or distributed work.
    Deduplicate skills and roles by name (case-insensitive). Extract languages only when the CV lists languages or proficiency (map to beginner, intermediate, advanced, or native; use intermediate when unclear).
    For each job, include description with responsibilities and achievements from that role; list skills under each job's skills array for tools or technologies named in that role's bullets (deduplicated per job). Include company_url and company_description only when explicitly on the CV; use empty strings when absent. The role description is used to populate the user's company record for that employer. Create one employer entry per distinct company_name (same employer across roles should repeat the same name).
    Extract reference_links for every visible LinkedIn, GitHub, GitLab, portfolio, or other http(s) link in headers, contact, or footer; use full https URLs; deduplicate by URL.
    The importer never creates duplicate user-owned rows: if work experience, education, certification, skill, role, language, company, or reference link already exists for the account (same identifying fields), it is reused and not overwritten.
    If no clear resume title exists, use the most prominent job title or a short professional label.
    Always include work_experiences, educations, certifications, skills, roles, languages, and reference_links as JSON arrays (each may be empty []).
  PROMPT

  class << self
    # When +extracted_payload+ is set (e.g. in tests), skips the PDF tempfile and RubyLLM call.
    def call(user:, role_id:, pdf_io: nil, extracted_payload: nil)
      raise ArgumentError, "pdf_io or extracted_payload is required" if pdf_io.nil? && extracted_payload.nil?

      user.roles.find_by!(id: role_id)

      extracted =
        if extracted_payload
          normalize_payload(extracted_payload)
        else
          tempfile = Tempfile.new([ "resume-import", ".pdf" ])
          tempfile.binmode
          IO.copy_stream(pdf_io, tempfile)
          tempfile.flush
          tempfile.rewind
          begin
            extract_from_pdf_path(tempfile.path)
          ensure
            tempfile.close!
          end
        end

      persist_from_payload!(user, role_id, extracted)
    end

    private

    def extract_from_pdf_path(path)
      model = ENV.fetch("RESUME_IMPORT_OPENAI_MODEL", "gpt-4.1-mini")
      chat = RubyLLM.chat(model: model).with_schema(Resume::PdfExtractSchema)
      response = chat.ask(EXTRACTION_PROMPT, with: path)
      normalize_payload(response.content)
    rescue RubyLLM::Error, Faraday::Error => e
      Rails.logger.error("[Resume::PdfImporter] extraction failed: #{e.class}: #{e.message}")
      raise Error, "Could not extract resume data from the PDF."
    end

    def normalize_payload(content)
      hash =
        case content
        when Hash
          content
        when String
          JSON.parse(content)
        else
          raise Error, "Unexpected response from language model."
        end
      hash.deep_stringify_keys
    rescue JSON::ParserError
      raise Error, "Unexpected response from language model."
    end

    def persist_from_payload!(user, role_id, payload)
      resume_meta = (payload["resume"] || {}).stringify_keys
      title = resume_meta["title"].to_s.strip.presence || "Imported resume"
      description = resume_meta["description"].to_s.strip.presence

      ActiveRecord::Base.transaction do
        preexisting_company_ids = user.companies.pluck(:id).to_set

        we_rows = Array(payload["work_experiences"]).filter_map do |row|
          persist_work_experience_row!(user, row, preexisting_company_ids: preexisting_company_ids)
        end
        work_experience_ids = we_rows.map(&:first)
        we_skill_ids = we_rows.flat_map(&:last)

        education_ids = Array(payload["educations"]).filter_map { |row| create_education!(user, row) }
        certification_ids = Array(payload["certifications"]).filter_map { |row| create_certification!(user, row) }
        skill_ids = (
          Array(payload["skills"]).filter_map { |row| find_or_create_skill!(user, row) } +
          we_skill_ids
        ).uniq
        Array(payload["roles"]).each { |row| find_or_create_role!(user, row) }
        Array(payload["languages"]).each { |row| find_or_create_language!(user, row) }
        Array(payload["reference_links"]).each { |row| find_or_create_reference_link!(user, row) }

        resume = user.resumes.create!(title: title, description: description, role_id: role_id)

        unless resume.sync_work_experience_links!(user, work_experience_ids)
          raise Error, "Failed to link work experiences to the resume."
        end
        unless resume.sync_certification_links!(user, certification_ids)
          raise Error, "Failed to link certifications to the resume."
        end
        unless resume.sync_education_links!(user, education_ids)
          raise Error, "Failed to link educations to the resume."
        end
        unless resume.sync_skill_links!(user, skill_ids)
          raise Error, "Failed to link skills to the resume."
        end

        resume.reload
      end
    end

    def persist_work_experience_row!(user, row, preexisting_company_ids:)
      row = row.to_h.stringify_keys
      return nil if row["title"].blank? || row["company_name"].blank?

      skill_ids = skill_ids_from_work_experience_skill_rows(user, row)

      existing_we = find_existing_work_experience(user, row)
      if existing_we
        import_skills_for_work_experience!(user, existing_we, skill_ids)
        return [ existing_we.id, skill_ids ]
      end

      upsert_company_from_experience_row!(user, row, preexisting_company_ids: preexisting_company_ids)

      we = user.work_experiences.create!(
        title: row["title"].to_s.strip,
        company_name: row["company_name"].to_s.strip,
        is_remote: cast_bool(row["is_remote"]),
        date_from: parse_date(row["date_from"]),
        date_to: parse_date(row["date_to"])
      )
      import_skills_for_work_experience!(user, we, skill_ids)
      [ we.id, skill_ids ]
    end

    def skill_ids_from_work_experience_skill_rows(user, row)
      row = row.to_h.stringify_keys
      Array(row["skills"]).filter_map do |entry|
        find_or_create_skill!(user, normalize_inline_skill_row(entry))
      end
    end

    def normalize_inline_skill_row(entry)
      case entry
      when Hash
        entry.to_h.stringify_keys
      else
        { "name" => entry.to_s, "description" => "" }
      end
    end

    def import_skills_for_work_experience!(user, work_experience, skill_ids)
      new_ids = Array(skill_ids).map(&:presence).compact.uniq
      return if new_ids.empty?

      combined = (work_experience.skill_ids + new_ids).uniq
      return if combined.sort == work_experience.skill_ids.sort

      unless work_experience.sync_skill_links!(user, combined)
        raise Error, "Failed to link skills to work experience."
      end
    end

    def find_existing_work_experience(user, row)
      title = row["title"].to_s.strip
      company_name = row["company_name"].to_s.strip
      date_from = parse_date(row["date_from"])
      date_to = parse_date(row["date_to"])

      user.work_experiences.where(
        "LOWER(title) = ? AND LOWER(company_name) = ?",
        title.downcase,
        company_name.downcase
      ).find do |we|
        dates_equal?(we.date_from, date_from) && dates_equal?(we.date_to, date_to)
      end
    end

    def upsert_company_from_experience_row!(user, row, preexisting_company_ids:)
      name = row["company_name"].to_s.strip
      return if name.blank?

      url = row["company_url"].to_s.strip.presence
      company_text = build_company_description_from_experience_row(row)

      existing = user.companies.where("LOWER(name) = ?", name.downcase).first
      if existing
        return if preexisting_company_ids.include?(existing.id)

        updates = {}
        updates[:url] = url if url.present? && existing.url.blank?
        if company_text.present?
          merged = merge_company_description(existing.description, company_text)
          updates[:description] = merged if merged != existing.description
        end
        existing.update!(updates) if updates.any?
        return
      end

      user.companies.create!(
        name: name,
        url: url,
        description: company_text,
        interest_level: 0
      )
    end

    def merge_company_description(current, addition)
      cur = current.to_s.strip
      add = addition.to_s.strip
      return add if cur.blank?
      return cur if add.blank?
      return cur if cur.include?(add)

      "#{cur}\n\n---\n\n#{add}"
    end

    def build_company_description_from_experience_row(row)
      tagline = row["company_description"].to_s.strip.presence
      job_body = row["description"].to_s.strip.presence
      [ tagline, job_body ].compact.join("\n\n").presence
    end

    def create_education!(user, row)
      row = row.to_h.stringify_keys
      return nil if row["institution_name"].blank?

      existing = find_existing_education(user, row)
      return existing.id if existing

      user.educations.create!(
        institution_name: row["institution_name"].to_s.strip,
        degree: row["degree"].to_s.strip.presence,
        field_of_study: row["field_of_study"].to_s.strip.presence,
        date_from: parse_date(row["date_from"]),
        date_to: parse_date(row["date_to"])
      ).id
    end

    def find_existing_education(user, row)
      inst = row["institution_name"].to_s.strip
      degree = row["degree"].to_s.strip.presence
      field = row["field_of_study"].to_s.strip.presence
      date_from = parse_date(row["date_from"])
      date_to = parse_date(row["date_to"])

      user.educations.where("LOWER(institution_name) = ?", inst.downcase).find do |ed|
        ed.degree.to_s.strip.presence == degree &&
          ed.field_of_study.to_s.strip.presence == field &&
          dates_equal?(ed.date_from, date_from) &&
          dates_equal?(ed.date_to, date_to)
      end
    end

    def create_certification!(user, row)
      row = row.to_h.stringify_keys
      return nil if row["name"].blank?

      existing = find_existing_certification(user, row)
      return existing.id if existing

      user.certifications.create!(
        name: row["name"].to_s.strip,
        date_from: parse_date(row["date_from"]),
        date_to: parse_date(row["date_to"])
      ).id
    end

    def find_existing_certification(user, row)
      name = row["name"].to_s.strip
      date_from = parse_date(row["date_from"])
      date_to = parse_date(row["date_to"])

      user.certifications.where("LOWER(name) = ?", name.downcase).find do |c|
        dates_equal?(c.date_from, date_from) && dates_equal?(c.date_to, date_to)
      end
    end

    def dates_equal?(a, b)
      (a.nil? && b.nil?) || a == b
    end

    def find_or_create_skill!(user, row)
      row = row.to_h.stringify_keys
      return nil if row["name"].blank?

      normalized = row["name"].to_s.strip
      existing = user.skills.where("LOWER(name) = ?", normalized.downcase).first
      return existing.id if existing

      user.skills.create!(
        name: normalized,
        description: row["description"].to_s.strip.presence
      ).id
    end

    def find_or_create_role!(user, row)
      row = row.to_h.stringify_keys
      return nil if row["name"].blank?

      normalized = row["name"].to_s.strip
      existing = user.roles.where("LOWER(name) = ?", normalized.downcase).first
      return existing.id if existing

      user.roles.create!(
        name: normalized,
        description: row["description"].to_s.strip.presence,
        interest_level: 0
      ).id
    end

    def find_or_create_language!(user, row)
      row = row.to_h.stringify_keys
      return nil if row["name"].blank?

      normalized = row["name"].to_s.strip
      existing = user.languages.where("LOWER(name) = ?", normalized.downcase).first
      return existing.id if existing

      level = normalize_language_level(row["level"])
      user.languages.create!(name: normalized, level: level).id
    end

    REFERENCE_LINK_HOST_LABELS = {
      "github.com" => "GitHub",
      "gitlab.com" => "GitLab",
      "linkedin.com" => "LinkedIn",
      "twitter.com" => "Twitter",
      "x.com" => "X",
      "medium.com" => "Medium",
      "stackoverflow.com" => "Stack Overflow",
      "dev.to" => "DEV"
    }.freeze

    def find_or_create_reference_link!(user, row)
      row = row.to_h.stringify_keys
      url = normalize_reference_url(row["url"])
      return nil if url.blank?

      title = row["title"].to_s.strip.presence || infer_reference_link_title(url)
      return nil if title.blank?

      existing_link = user.reference_links.find_by("LOWER(url) = ?", url.downcase)
      return existing_link.id if existing_link

      user.reference_links.create!(title: title, url: url).id
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[Resume::PdfImporter] reference_link skipped: #{e.message}")
      nil
    end

    def normalize_reference_url(raw)
      s = raw.to_s.strip
      return nil if s.blank?
      s = "https://#{s}" unless s.match?(/\A[a-z][a-z0-9+\-.]*:/i)
      uri = URI.parse(s)
      return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return nil if uri.host.blank?

      scheme = uri.scheme&.casecmp("http")&.zero? ? "http" : "https"
      host = uri.host.downcase
      path = uri.path.to_s
      path = path[0..-2] while path.length > 1 && path.end_with?("/")
      q = uri.query.present? ? "?#{uri.query}" : ""
      f = uri.fragment.present? ? "##{uri.fragment}" : ""
      "#{scheme}://#{host}#{path}#{q}#{f}"
    rescue URI::InvalidURIError, ArgumentError, TypeError
      nil
    end

    def infer_reference_link_title(url)
      uri = URI.parse(url)
      host = uri.host&.downcase&.delete_prefix("www.") || ""
      REFERENCE_LINK_HOST_LABELS[host] || host.split(".").first&.capitalize.presence || "Website"
    rescue URI::InvalidURIError, ArgumentError
      "Link"
    end

    def normalize_language_level(value)
      s = value.to_s.strip.downcase.tr(" ", "_")
      return s if Language::LEVELS.include?(s)

      case s
      when "fluent", "full_professional", "professional_working", "bilingual"
        "advanced"
      when "elementary", "basic", "a1", "a2"
        "beginner"
      when "limited_working", "working_knowledge", "b1", "b2"
        "intermediate"
      when "full_professional_proficiency", "c1", "c2", "mother_tongue", "native_or_bilingual"
        "native"
      else
        "intermediate"
      end
    end

    def parse_date(value)
      s = value.to_s.strip
      return nil if s.blank?

      Date.iso8601(s)
    rescue ArgumentError
      Date.parse(s)
    rescue ArgumentError, TypeError
      nil
    end

    def cast_bool(value)
      return false if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
