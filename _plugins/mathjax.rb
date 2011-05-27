# MathJax Block
# Roughly based on Jekyll's HighlightBlock
module Jekyll

  class MathJaxBlock < Liquid::Block
    include Liquid::StandardFilters

    # Detect if we need to use block display style
    SYNTAX = /(display)?/

    def initialize(tag_name, markup,tokens)
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
      # Render inline
      "<span class=\"MathJax_Preview\">#{h(math).strip}</span><script type=\"math/tex\">#{math.strip}</script>"
    end

    def render_display(context, math)
      # Since this is a block style formula, wrap it in a paragraph
      <<-HTML
<p>
  <span class="MathJax_Preview">#{h(math).strip}</span><script type="math/tex; mode=display">
  #{math.strip}
  </script>
</p>
      HTML
    end
  end
end

Liquid::Template.register_tag('math', Jekyll::MathJaxBlock)
