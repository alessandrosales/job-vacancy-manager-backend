# frozen_string_literal: true

# Maps `users.preferred_language` / Accept-Language to Rails locales (rails-i18n uses :"pt-BR").
class ApiLocale
  STORAGE_TO_I18N = {
    "en" => :en,
    "pt_br" => :"pt-BR",
    "es" => :es,
  }.freeze

  I18N_TO_STORAGE = STORAGE_TO_I18N.invert.freeze

  class << self
    def normalize_storage_code(raw)
      s = raw.to_s.strip.downcase.tr("-", "_")
      return nil if s.blank?

      return "pt_br" if s == "pt_br" || s == "pt" || s == "ptbr" || s.start_with?("pt_")
      return "es" if s == "es" || s.start_with?("es_")
      return "en" if s == "en" || s.start_with?("en_")

      nil
    end

    def from_storage_or_header(preferred_language_code:, accept_language: nil)
      code = normalize_storage_code(preferred_language_code)
      return STORAGE_TO_I18N.fetch(code, I18n.default_locale) if code

      locale_from_accept_language_header(accept_language) || I18n.default_locale
    end

    def locale_from_accept_language_header(header)
      return nil if header.blank?

      header.split(",").each do |part|
        tag = part.split(";").first&.strip&.downcase&.tr("_", "-")
        next if tag.blank?

        key = normalize_storage_code(tag.gsub("-", "_"))
        loc = STORAGE_TO_I18N[key] if key
        return loc if loc
      end
      nil
    end
  end
end
