# frozen_string_literal: true

# Percorre o AST do Kramdown e emite markup Caracal (sem alterar o texto-fonte).
class Resume::CompiledExport::DocxRenderer
  def initialize(docx)
    @docx = docx
  end

  def render(markdown)
    tree = Kramdown::Document.new(markdown).root
    tree.children.each { |el| render_root_element(el) }
  end

  def self.plain_text(el)
    case el.type
    when :text
      el.value.to_s
    when :smart_quote, :typographic_sym
      el.value.to_s
    when :entity
      entity_text(el)
    else
      el.children.map { |c| plain_text(c) }.join
    end
  end

  def self.entity_text(el)
    val = el.value
    return "" if val.nil?

    val.to_s
  end

  private_class_method :entity_text

  # Chamadas destes métodos com receptor explícito ocorrem a partir de blocos do Caracal
  # (+instance_eval+ em modelos internos); não podem ser +private+/+protected+.

  def render_ul_children(list_model, ul_el)
    renderer = self
    ul_el.children.each do |li_el|
      next unless li_el.type == :li

      list_model.li do
        renderer.render_li_body(self, li_el)
      end
    end
  end

  def render_ol_children(list_model, ol_el)
    renderer = self
    ol_el.children.each do |li_el|
      next unless li_el.type == :li

      list_model.li do
        renderer.render_li_body(self, li_el)
      end
    end
  end

  def render_li_body(item_ctx, li_el)
    renderer = self
    li_el.children.each do |child|
      case child.type
      when :p
        if fenced_codespan_only?(child)
          code = child.children.first.value.to_s.gsub(/\A\n/, "").gsub(/\n\z/, "")
          item_ctx.text(code.presence || " ", italic: true)
        elsif child.children.any?
          renderer.emit_inline_runs(item_ctx, child.children)
        end
      when :ul
        item_ctx.ul do
          renderer.render_ul_children(self, child)
        end
      when :ol
        item_ctx.ol do
          renderer.render_ol_children(self, child)
        end
      when :blank
        nil
      else
        renderer.emit_inline_runs(item_ctx, [ child ])
      end
    end
  end

  def emit_inline_runs(para, elements, bold: false, italic: false)
    elements.each do |el|
      case el.type
      when :text
        str = el.value
        next if str.nil?

        opts = {}
        opts[:bold] = true if bold
        opts[:italic] = true if italic
        if opts.empty?
          para.text str
        else
          para.text str, opts
        end
      when :strong
        emit_inline_runs(para, el.children, bold: true, italic: italic)
      when :em
        emit_inline_runs(para, el.children, bold: bold, italic: true)
      when :codespan
        para.text el.value.to_s, italic: true
      when :a
        href = el.attr["href"].to_s
        label = self.class.plain_text(el)
        if href.present?
          para.link label, href
        else
          emit_inline_runs(para, el.children, bold: bold, italic: italic)
        end
      when :entity
        txt = self.class.plain_text(el)
        para.text txt if txt.present?
      when :smart_quote, :typographic_sym
        para.text el.value.to_s
      when :line_break
        para.br
      else
        fallback = self.class.plain_text(el)
        para.text fallback if fallback.present?
      end
    end
  end

  private

  def render_root_element(el)
    case el.type
    when :blank
      nil
    when :header
      render_header(el)
    when :p
      render_paragraph_block(el)
    when :ul
      render_ul_root(el)
    when :ol
      render_ol_root(el)
    when :hr
      @docx.hr
    when :blockquote
      el.children.each { |child| render_root_element(child) }
    when :codeblock
      @docx.p self.class.plain_text(el).presence || " ", italic: true
    else
      t = self.class.plain_text(el).strip
      @docx.p t if t.present?
    end
  end

  def render_header(el)
    level = el.options[:level].to_i
    level = 1 if level < 1
    level = 6 if level > 6
    text = self.class.plain_text(el).strip
    return if text.blank?

    @docx.public_send(:"h#{level}", text)
  end

  def render_paragraph_block(p_el)
    if fenced_codespan_only?(p_el)
      code = p_el.children.first.value.to_s.gsub(/\A\n/, "").gsub(/\n\z/, "")
      @docx.p(code.presence || " ", italic: true)
      return
    end

    runs = p_el.children
    return if runs.empty?

    renderer = self
    @docx.p do
      renderer.emit_inline_runs(self, runs)
    end
  end

  def fenced_codespan_only?(p_el)
    return false unless p_el.children.size == 1

    child = p_el.children.first
    return false unless child.type == :codespan

    delim = child.options[:codespan_delimiter].to_s
    delim.length >= 3
  end

  def render_ul_root(ul_el)
    renderer = self
    @docx.ul do
      renderer.render_ul_children(self, ul_el)
    end
  end

  def render_ol_root(ol_el)
    renderer = self
    @docx.ol do
      renderer.render_ol_children(self, ol_el)
    end
  end
end
