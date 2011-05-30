# MathJax Block
# Roughly based on Jekyll's HighlightBlock
module Jekyll

  class MathJaxBlock < Liquid::Block
    include Liquid::StandardFilters

    # Detect if we need to use block display style
    SYNTAX = /(display)?/

    def initialize(tag_name, markup, tokens)
      super
      if markup =~ SYNTAX
        if defined? $1
          @inline = false
        else
          @inline = true
        end
      else
        raise SyntaxError.new("Syntax Error in 'math' - Valid syntax: math [display]")
      end
    end

    def render(context)
      if @inline
        render_inline(context, super.join)
      else
        render_display(context, super.join)
      end
    end

    def render_inline(context, math)
      "<script type=\"math/tex\">#{h(math).strip}</script>"
    end

    def render_display(context, math)
      <<-HTML
<p style="text-align: center">
<script type="math/tex; mode=display">
#{h(math).strip}
</script>
</p>
      HTML
    end
  end

  # Ugly monkeypatch for inline formula post-processing
  class Site
    alias_method :original_render, :render
    def render
      original_render

      # Post-process posts and pages
      self.posts.each do |post|
        fix_math(post)
      end

      self.pages.each do |page|
        fix_math(page)
      end
    end

    def fix_math(p)
      # Get rid of the <script> tags and add proper MathJax delimiters
      # Inline math
      p.output.gsub!(/(<script type="math\/tex">)(.*?)(<\/script>)/m, '\( \2 \)')
      # Display-style math
      p.output.gsub!(/(<script type="math\/tex; mode=display">\n)(.*?)(<\/script>)/m, "$$\n\\2$$")
    end
  end
end

Liquid::Template.register_tag('math', Jekyll::MathJaxBlock)
