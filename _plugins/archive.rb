module Jekyll

  # ArchiveIndex class creates a single archive page for the specified archive
  class ArchiveIndex < Page
    def initialize(site, base, dir, type)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), type + '.html')

      # Set year, month (if any) and day (if any)
      year, month, day = dir.split('/')
      self.data['year'] = year.to_i
      month and self.data['month'] = month.to_i
      day and self.data['day'] = day.to_i

      # Set the title for this page
      title_prefix = site.config['archive_title_prefix'] || 'Archive: '
      self.data['title'] = "#{title_prefix}#{year}"
      month and self.data['title'] += " &raquo; #{Jekyll::Filters::Months[month.to_i]}"
      day and self.data['title'] += " &raquo; #{day}"
      # Meta description for this page
      meta_description_prefix = site.config['archive_meta_description_prefix'] || 'Archive: '
      self.data['description'] = "#{meta_description_prefix}#{year}"
      month and self.data['description'] += "/#{month}"
      day and self.data['description'] += "/#{day}"
    end
  end

  # Jekyll hook
  class ArchiveGenerator < Generator
    safe true

    def write_archive_index(site, archive_dir, posts, type)
      index = ArchiveIndex.new(site, site.source, archive_dir, type)

      pages = Pager.calculate_pages(posts, site.config['paginate'].to_i)
      (1..pages).each do |num_page|
        pager = Pager.new(site.config, num_page, posts, pages)
        if num_page > 1
          newpage = ArchiveIndex.new(site, site.source, archive_dir, type)
          newpage.pager = pager
          newpage.dir = File.join(archive_dir, "page/#{num_page}")
          site.pages << newpage
        else
          index.pager = pager
        end
      end

      site.pages << index
    end

    # Loop through the list of archive pages and process each one
    def generate(site)
      collated_posts = site.posts.inject({}) do |h, post|
        (((h[post.year] ||= {})[post.month] ||= {})[post.day] ||= []) << post
        h
      end
      collated_posts.keys.each do |year|
        yposts = []
        collated_posts[year].keys.each do |month|
          mposts = []
          collated_posts[year][month].keys.each do |day|
            write_archive_index(site, "%04d/%02d/%02d" % [year.to_i, month.to_i, day.to_i], collated_posts[year][month][day].reverse, 'archive_daily') if site.layouts.key? 'archive_daily'
            mposts += collated_posts[year][month][day]
          end
          write_archive_index(site, "%04d/%02d" % [year.to_i, month.to_i], mposts.reverse, 'archive_monthly') if site.layouts.key? 'archive_monthly'
          yposts += mposts
        end
        write_archive_index(site, year.to_s, yposts.reverse, 'archive_yearly') if site.layouts.key? 'archive_yearly'
      end
    end
  end

  class Post
    def year
      @year ||= date.strftime("%Y")
    end

    def month
      @month ||= date.strftime("%m")
    end

    def day
      @day ||= date.strftime("%d")
    end
  end

  module Filters
    Months = %w(None Gennaio Febbraio Marzo Aprile Maggio Giugno Luglio Agosto Settembre Ottobre Novembre Dicembre)
  end
end
