module Liquid

  module ExtendedFilters

    def date_to_month(input)
      Jekyll::Filters::Months[input]
    end

    def slugify(t)
      t = t.gsub(/%([a-f0-9]{2})/i, '---\1---').gsub(/%/, '').gsub(/---([a-f0-9]{2})---/i, '\1').downcase
      t.gsub(/&.+?;/, '').gsub(/\./, '-').gsub(/[^%a-z0-9 _-]/, '').gsub(/\s+/, '-').gsub(/-+/, '-').gsub(/^-+/, '').gsub(/-+$/, '')
    end

    def preview(text, delimiter = '<!-- end_preview -->')
      if text.index(delimiter) != nil
        text.split(delimiter)[0]
      else
        text
      end
    end

    def escape_javascript(javascript)
      (javascript || '').gsub('\\', '\0\0').gsub('</', '<\/').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
    end

    def categories_meta(categories)
      catlinks = []
      categories.each { |cat| catlinks << "<a href='/category/#{slugify(cat)}'>#{cat}</a>" }
      catlinks.join(', ')
    end
  end

  module ExtendedTags

    class MathJaxInlineBegin < Liquid::Tag
      def render(context)
        '<span class="MathJax_Preview">[math]</span><script type="math/tex">'
      end
    end

    class MathJaxInlineEnd < Liquid::Tag
      def render(context)
        '</script>'
      end
    end

    class MathJaxBlockBegin < Liquid::Tag
      def render(context)
        '<p><span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'
      end
    end

    class MathJaxBlockEnd < Liquid::Tag
      def render(context)
        '</script></p>'
      end
    end

    class RenderTimeTag < Liquid::Tag
      def initialize(tag_name, text, tokens)
        super
        @text = text
      end

      def render(context)
        "#{@text} #{Time.now}"
      end
    end
  end

  Liquid::Template.register_filter(ExtendedFilters)

  # Register tags
  Liquid::Template.register_tag('math', ExtendedTags::MathJaxBlockBegin)
  Liquid::Template.register_tag('endmath', ExtendedTags::MathJaxBlockEnd)
  Liquid::Template.register_tag('m', ExtendedTags::MathJaxInlineBegin)
  Liquid::Template.register_tag('em', ExtendedTags::MathJaxInlineEnd)
  Liquid::Template.register_tag('render_time', ExtendedTags::RenderTimeTag)
end
