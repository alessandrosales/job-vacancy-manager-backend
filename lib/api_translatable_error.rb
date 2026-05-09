# frozen_string_literal: true

# Raised by domain objects that expose an I18n key for API JSON errors.
class ApiTranslatableError < StandardError
  attr_reader :i18n_key

  def initialize(i18n_key)
    @i18n_key = i18n_key
    super(i18n_key.to_s)
  end

  def translate
    I18n.t(i18n_key)
  end
end
