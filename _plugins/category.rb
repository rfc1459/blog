module Jekyll

  class CategoryIndex < Page
    def initialize(site, base, dir, category)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'category_index.html')
      self.data['category'] = category

      category_title_prefix = site.config['category_title_prefix'] || 'Category: '
      self.data['title'] = "#{category_title_prefix}#{category}"
    end
  end

  class CategoryGenerator < Generator
    safe true

    def generate(site)
      if site.layouts.key? 'category_index'
        dir = '/' + (site.config['category_dir'] || 'categories')
        site.categories.keys.each do |category|
          write_category_index(site, File.join(dir, slugify(category)), category)
        end
      end
    end

    def slugify(t)
      t = t.gsub(/%([a-f0-9]{2})/i, '---\1---').gsub(/%/, '').gsub(/---([a-f0-9]{2})---/i, '\1').downcase
      t.gsub(/&.+?;/, '').gsub(/\./, '-').gsub(/[^%a-z0-9 _-]/, '').gsub(/\s+/, '-').gsub(/-+/, '-').gsub(/^-+/, '').gsub(/-+$/, '')
    end

    def write_category_index(site, dir, category)
      index = CategoryIndex.new(site, site.source, dir, category)

      posts = site.categories[category].sort.reverse
      pages = Pager.calculate_pages(posts, site.config['paginate'].to_i)
      (1..pages).each do |num_page|
        pager = Pager.new(site.config, num_page, posts, pages)
        if num_page > 1
          newpage = CategoryIndex.new(site, site.source, dir, category)
          newpage.pager = pager
          newpage.dir = File.join(dir, "page/#{num_page}")
          site.pages << newpage
        else
          index.pager = pager
        end
      end

      site.pages << index
    end
  end
end
