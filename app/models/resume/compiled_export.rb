# frozen_string_literal: true

# Exporta o texto já persistido em +compiled_markdown+ como arquivo (sem recompilar).
class Resume::CompiledExport
  class Error < StandardError; end

  FORMATS = %w[md docx pdf].freeze

  Result = Struct.new(:bytes, :filename, :content_type, keyword_init: true)

  def self.render(resume:, format:)
    new(resume: resume, format: format.to_s.downcase.strip).render
  end

  def initialize(resume:, format:)
    @resume = resume
    @format = format
  end

  def render
    validate!
    case @format
    when "md"
      Result.new(
        bytes: @resume.compiled_markdown.dup.force_encoding(Encoding::UTF_8),
        filename: filename_for("md"),
        content_type: "text/markdown; charset=utf-8"
      )
    when "pdf"
      Result.new(
        bytes: render_pdf_bytes,
        filename: filename_for("pdf"),
        content_type: "application/pdf"
      )
    when "docx"
      Result.new(
        bytes: render_docx_bytes,
        filename: filename_for("docx"),
        content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      )
    end
  end

  private

  def validate!
    unless FORMATS.include?(@format)
      raise Error, "Export format is invalid."
    end

    if @resume.compiled_markdown.blank?
      raise Error, "Compiled markdown is not available yet."
    end
  end

  def filename_for(ext)
    "#{base_slug}.#{ext}"
  end

  def base_slug
    @resume.title.to_s.parameterize.presence || "resume"
  end

  def render_pdf_bytes
    require "prawn"

    Prawn::Fonts::AFM.hide_m17n_warning = true

    m = Resume::CompiledExport::PdfRenderer::MARGIN
    pdf = Prawn::Document.new(
      margin: [ m, m, m, m ],
      page_size: "LETTER"
    )
    pdf.font("Helvetica")
    pdf.font_size(Resume::CompiledExport::PdfRenderer::BODY_SIZE)
    pdf.default_leading(Resume::CompiledExport::PdfRenderer::BODY_LEADING)

    Resume::CompiledExport::PdfRenderer.new(pdf).render(@resume.compiled_markdown)
    pdf.render
  rescue StandardError => e
    Rails.logger.error("[Resume::CompiledExport] PDF failed: #{e.class}: #{e.message}")
    raise Error, "Could not generate PDF from compiled markdown."
  end

  def render_docx_bytes
    Caracal::Document.render(nil) do |docx|
      Resume::CompiledExport::DocxRenderer.new(docx).render(@resume.compiled_markdown)
    end
  rescue Caracal::Errors::InvalidModelError => e
    raise Error, e.message
  rescue StandardError => e
    Rails.logger.error("[Resume::CompiledExport] DOCX failed: #{e.class}: #{e.message}")
    raise Error, "Could not generate DOCX from compiled markdown."
  end
end
