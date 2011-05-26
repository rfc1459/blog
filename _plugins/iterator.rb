module Jekyll

  class Site
    alias_method :orig_site_payload, :site_payload

    def make_iterable(kv_hash, options)
      options = {:index => 'name', :items => 'items'}.merge(options)
      result = []
      kv_hash.sort.each do |key, value|
        result << { options[:index] => key, options[:items] => value }
      end
      result
    end

    def site_payload
      payload = orig_site_payload
      payload['site']['iterable'] = {
        'categories'  => make_iterable(self.categories, :index => 'name', :items => 'posts'),
        'tags'        => make_iterable(self.tags, :index => 'name', :items => 'posts')
      }
      payload
    end
  end

end
