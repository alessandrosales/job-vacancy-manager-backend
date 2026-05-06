# frozen_string_literal: true

# Percorre o AST do Kramdown e desenha no Prawn com hierarquia tipográfica compacta (estilo currículo ATS).
class Resume::CompiledExport::PdfRenderer
  MARGIN = 48
  BODY_SIZE = 10
  BODY_LEADING = 3.5
  LIST_INDENT = 14
  HR_COLOR = "999999"
  LINK_COLOR = "1a4b8c"

  # H1 = nome; H2 = seções; H3 = subtítulos (ex.: cargo); corpo legível sem competir com títulos.
  HEADING_STYLES = {
    1 => { size: 14, space_before: 0, space_after: 5 },
    2 => { size: 11, space_before: 10, space_after: 4 },
    3 => { size: 10.25, space_before: 6, space_after: 3 },
    4 => { size: 10, space_before: 4, space_after: 2 },
    5 => { size: 9.75, space_before: 3, space_after: 2 },
    6 => { size: 9.5, space_before: 3, space_after: 2 }
  }.freeze

  def initialize(pdf)
    @pdf = pdf
    @block_index = 0
  end

  def render(markdown)
    tree = Kramdown::Document.new(markdown).root
    tree.children.each { |el| render_root_element(el) }
  end

  def self.plain_text(el)
    Resume::CompiledExport::DocxRenderer.plain_text(el)
  end

  private

  def vertical_space_before_block(style)
    pad = style[:space_before] || 0
    return if pad <= 0

    @pdf.move_down(pad)
  end

  def vertical_space_after_block(style)
    pad = style[:space_after] || 0
    @pdf.move_down(pad) if pad.positive?
  end

  def render_root_element(el)
    case el.type
    when :blank
      @pdf.move_down(4)
    when :header
      render_header(el)
    when :p
      render_paragraph_block(el)
    when :ul
      render_ul(el, depth: 0)
    when :ol
      render_ol(el, depth: 0, start: 1)
    when :hr
      draw_horizontal_rule
    when :blockquote
      @pdf.indent(10, 0) do
        el.children.each { |c| render_root_element(c) }
      end
    when :codeblock
      t = self.class.plain_text(el).presence || " "
      @pdf.move_down(4)
      @pdf.font_size(BODY_SIZE - 1) do
        @pdf.text t, style: :italic, leading: BODY_LEADING
      end
      @pdf.move_down(4)
    else
      t = self.class.plain_text(el).strip
      return if t.blank?

      @pdf.move_down(2) if @block_index.positive?
      @pdf.text t, size: BODY_SIZE, leading: BODY_LEADING
      @block_index += 1
    end
  end

  def render_header(el)
    level = el.options[:level].to_i
    level = 1 if level < 1
    level = 6 if level > 6
    text = self.class.plain_text(el).strip
    return if text.blank?

    style = HEADING_STYLES[level]
    vertical_space_before_block(style)

    @pdf.font_size(style[:size]) do
      @pdf.text text, style: :bold, leading: 1.2
    end

    vertical_space_after_block(style)
    @block_index += 1
  end

  def render_paragraph_block(p_el)
    if fenced_codespan_only?(p_el)
      code = p_el.children.first.value.to_s.gsub(/\A\n/, "").gsub(/\n\z/, "")
      @pdf.move_down(2) if @block_index.positive?
      @pdf.font_size(BODY_SIZE - 0.5) do
        @pdf.text(code.presence || " ", style: :italic, leading: BODY_LEADING)
      end
      @pdf.move_down(3)
      @block_index += 1
      return
    end

    runs = p_el.children
    return if runs.empty?

    fragments = build_fragments(runs, bold: false, italic: false, size: BODY_SIZE)
    return if fragments.empty?

    @pdf.move_down(2) if @block_index.positive?
    @pdf.formatted_text(fragments, leading: BODY_LEADING)
    @pdf.move_down(3)
    @block_index += 1
  end

  def fenced_codespan_only?(p_el)
    return false unless p_el.children.size == 1

    child = p_el.children.first
    return false unless child.type == :codespan

    child.options[:codespan_delimiter].to_s.length >= 3
  end

  def draw_horizontal_rule
    @pdf.move_down(6)
    y = @pdf.cursor
    @pdf.stroke_color(HR_COLOR)
    @pdf.line_width(0.5)
    @pdf.stroke_horizontal_line(@pdf.bounds.left, @pdf.bounds.right, at: y)
    @pdf.stroke_color("000000")
    @pdf.line_width(1)
    @pdf.move_down(10)
  end

  def render_ul(ul_el, depth:)
    ul_el.children.each do |li_el|
      next unless li_el.type == :li

      gutter = LIST_INDENT + (depth * 12)
      @pdf.indent(gutter, 0) do
        render_li_blocks(li_el, depth: depth, bullet: "• ")
      end
    end
    @pdf.move_down(4)
  end

  def render_ol(ol_el, depth:, start:)
    n = start - 1
    ol_el.children.each do |li_el|
      next unless li_el.type == :li

      n += 1
      gutter = LIST_INDENT + (depth * 12)
      @pdf.indent(gutter, 0) do
        render_li_blocks(li_el, depth: depth, bullet: "#{n}. ")
      end
    end
    @pdf.move_down(4)
  end

  def render_li_blocks(li_el, depth:, bullet:)
    li_el.children.each do |child|
      case child.type
      when :p
        if fenced_codespan_only?(child)
          code = child.children.first.value.to_s.gsub(/\A\n/, "").gsub(/\n\z/, "")
          fr = bullet_fragments(bullet) + [
            { text: code.presence || " ", size: BODY_SIZE - 0.5, styles: [ :italic ] }
          ]
          @pdf.formatted_text(fr, leading: BODY_LEADING)
        else
          body = build_fragments(child.children, bold: false, italic: false, size: BODY_SIZE)
          next if body.empty?

          @pdf.formatted_text(bullet_fragments(bullet) + body, leading: BODY_LEADING)
        end
        @pdf.move_down(2)
      when :ul
        render_ul(child, depth: depth + 1)
      when :ol
        render_ol(child, depth: depth + 1, start: 1)
      when :blank
        nil
      else
        body = build_fragments([ child ], bold: false, italic: false, size: BODY_SIZE)
        next if body.empty?

        @pdf.formatted_text(bullet_fragments(bullet) + body, leading: BODY_LEADING)
        @pdf.move_down(2)
      end
    end
  end

  def bullet_fragments(bullet)
    [ { text: bullet, size: BODY_SIZE, styles: [ :bold ] } ]
  end

  def build_fragments(elements, bold:, italic:, size:)
    fragments = []
    elements.each do |el|
      case el.type
      when :text
        str = el.value
        next if str.nil? || str.empty?

        frag = { text: str, size: size }
        styles = []
        styles << :bold if bold
        styles << :italic if italic
        frag[:styles] = styles if styles.any?
        fragments << frag
      when :strong
        fragments.concat(build_fragments(el.children, bold: true, italic: italic, size: size))
      when :em
        fragments.concat(build_fragments(el.children, bold: bold, italic: true, size: size))
      when :codespan
        fragments << { text: el.value.to_s, size: size - 0.5, styles: [ :italic ] }
      when :a
        href = el.attr["href"].to_s
        label = self.class.plain_text(el)
        next if label.empty?

        frag = { text: label, size: size }
        styles = []
        styles << :bold if bold
        styles << :italic if italic
        frag[:styles] = styles if styles.any?
        frag[:color] = LINK_COLOR if href.present?
        frag[:link] = href if href.present?
        fragments << frag
      when :entity, :smart_quote, :typographic_sym
        txt = self.class.plain_text(el)
        next if txt.empty?

        frag = { text: txt, size: size }
        styles = []
        styles << :bold if bold
        styles << :italic if italic
        frag[:styles] = styles if styles.any?
        fragments << frag
      when :line_break
        fragments << { text: "\n", size: size }
      else
        fallback = self.class.plain_text(el)
        next if fallback.strip.empty?

        frag = { text: fallback, size: size }
        styles = []
        styles << :bold if bold
        styles << :italic if italic
        frag[:styles] = styles if styles.any?
        fragments << frag
      end
    end
    fragments
  end
end
