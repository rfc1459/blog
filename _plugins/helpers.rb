require 'nokogiri'

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

    def fix_math(t)
      t.gsub(/(<script type="math\/tex">)(.*?)(<\/script>)/m, '\( \2 \)').gsub(/(<script type="math\/tex; mode=display">\n)(.*?)(<\/script>)/m, "$$\n\\2$$")
    end

    def rss_preview(text, delimiter = '<!-- end_preview -->')
      if text.index(delimiter) != nil
        doc = Nokogiri::HTML::DocumentFragment.parse text.split(delimiter)[0]
        rt = doc.inner_text
      else
        rt = truncate_html(:text => text, :ellipsis => '[...]', :max_length => 300)
      end
      rt.gsub(/\n/, ' ').gsub(/\s{2,}/, ' ')
    end

    def escape_javascript(javascript)
      (javascript || '').gsub('\\', '\0\0').gsub('</', '<\/').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
    end

    def categories_meta(categories)
      catlinks = []
      categories.each { |cat| catlinks << "<a href='/category/#{slugify(cat)}'>#{cat}</a>" }
      catlinks.join(', ')
    end

    def truncate_html(params)
      text = params[:text] || raise("text parameter is required")
      max_length = params[:max_length] || 200
      ellipsis = params[:ellipsis] || ""
      ellipsis_length = ellipsis.length
      doc = Nokogiri::HTML::DocumentFragment.parse text
      content_length = doc.inner_text.length
      actual_length = max_length - ellipsis_length
      content_length > actual_length ? doc.truncate(actual_length).inner_text + ' ' + ellipsis : doc.inner_text
    end
  end

  module ExtendedTags
    class RenderTimeTag < Liquid::Tag
      def initialize(tag_name, text, tokens)
        super
        @text = text
      end

      def render(context)
        "#{@text} #{Time.now}"
      end
    end

    class AudioPlayerTag < Liquid::Tag
      SYNTAX = /(#{Liquid::QuotedFragment}+)/
      def initialize(tag_name, markup, tokens)
        if markup =~ SYNTAX
          @file_url = $1
          @attributes = {}
          markup.scan(Liquid::TagAttributes) do |key, value|
            @attributes[key] = value
          end
          unless @attributes.has_key? 'id'
            raise Liquid::SyntaxError.new("Error in tag 'audio' - Valid syntax: audio 'url' id:number")
          end
        else
          raise Liquid::SyntaxError.new("Error in tag 'audio' - Valid syntax: audio 'url' id:number")
        end

        super
      end

      def render(context)
        id = @attributes.delete 'id'
        attrs = ["soundFile: \"#{@file_url}\""]
        @attributes.each do |k, v|
          attrs.push "#{k}: #{v}"
        end
        attrs = attrs.join ",\n    "
        <<-HTML
<p id="audioplayer_#{id}"><a href="#{@file_url}">#{@file_url}</a></p>
<script type="text/javascript">
//<![CDATA[
  AudioPlayer.embed("audioplayer_#{id}", {
    #{attrs}
  });
//]]>
</script>
        HTML
      end
    end
  end

  module NokogiriTruncator
    module NodeWithChildren
      def truncate(max_length)
        return self if inner_text.length <= max_length
        truncated_node = self.dup
        truncated_node.children.remove

        self.children.each do |node|
          remaining_length = max_length - truncated_node.inner_text.length
          break if remaining_length <= 0
          truncated_node.add_child node.truncate(remaining_length)
        end
        truncated_node
      end
    end

    module TextNode
      def truncate(max_length)
        # Approximate truncation at nearest space
        Nokogiri::XML::Text.new(content.gsub(/^(.{#{max_length}}[^\s]*)(?:.*)/m, '\1'), parent)
      end
    end
  end

  # Register nokogiri extensions
  Nokogiri::HTML::DocumentFragment.send(:include, NokogiriTruncator::NodeWithChildren)
  Nokogiri::XML::Element.send(:include, NokogiriTruncator::NodeWithChildren)
  Nokogiri::XML::Text.send(:include, NokogiriTruncator::TextNode)

  # Register filters
  Liquid::Template.register_filter(ExtendedFilters)

  # Register tags
  Liquid::Template.register_tag('render_time', ExtendedTags::RenderTimeTag)
  Liquid::Template.register_tag('audio', ExtendedTags::AudioPlayerTag)
end
