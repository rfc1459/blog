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
      # Render inline - we cannot generate a CDATA elementa here because rdiscount would
      # screw up the whole paragraph flow.
      "<span class=\"MathJax_Preview\">#{h(math).strip}</span><script type=\"math/tex\">#{math.strip}</script>"
    end

    def render_display(context, math)
      # Since this is a block style formula, wrap it in a paragraph
      # Also, wrap the source into a CDATA element to prevent mangling by HTMLTidy
      <<-HTML
<p style="text-align: center">
  <span class="MathJax_Preview">#{h(math).strip}</span><script type="math/tex; mode=display">
%<![CDATA[
  #{math.strip}
%]]>
  </script>
</p>
      HTML
    end
  end

  # Ugly monkeypatch for inline formula post-processing
  class Site
    alias_method :original_write, :write
    def write
      # Before writing, post-process posts and pages
      self.posts.each do |p|
        fix_inline_math(p)
      end
      self.pages.each do |p|
        fix_inline_math(p)
      end
      # Now write everything
      original_write
    end

    def fix_inline_math(page)
      # Inject a CDATA element with appropriate LaTeX comment delimiters inside inline formulas
      page.output.gsub!(/(<script type="math\/tex">)(.*?)(<\/script>)/m, "\\1\n%<![CDATA[\n\\2\n%]]>\n\\3")
    end
  end
end

Liquid::Template.register_tag('math', Jekyll::MathJaxBlock)
