%w(rubygems bundler date).each{|g| require g}

deploy_host = 'blog'
deploy_path = 'blog'
site_url    = 'http://morpheus.level28.org'
site        = '_site'
editor      = 'mate'

task :default => :publish

desc 'Generate and publish the entire site'
task :publish => [:build, :sync] do
end

desc 'List Tasks'
task :list do
  puts "Tasks: #{(Rake::Task.tasks - [Rake::Task[:list]]).to_sentence}"
  puts "(type rake -T for more details)\n\n"
end

desc 'Build the site'
task :build => [:compass, :jekyll, :tidy, :compress] do
end

desc 'Create CSS files with compass'
task :compass do
  puts '* Generating CSS files'
  system 'compass compile'
end

desc 'Generate site with jekyll'
task :jekyll do
  puts '* Running jekyll'
  system 'jekyll'
end

desc 'Clean up generated HTML files with tidy'
task :tidy do
  puts '* Running tidy'
  system "find #{site} -name '*.html' -not -name 'google*.html' -type f -exec tidy -config tidy.conf {} \\;"
end

desc 'Pre-compress all files with gzip'
task :compress do
  puts '* Compressing files'
  %w(html css js xml txt).each do |type|
    system "find #{site} -name '*.#{type}' -type f -exec bash -c \"gzip -9 -c '{}' > '{}.gz'; touch -c -r '{}' '{}.gz'\" \\;"
  end
end

desc 'Push the generated site to the server'
task :sync do
  puts '* Publishing files'
  system "rsync -avzc --delete -e ssh #{site}/ #{deploy_host}:#{deploy_path}"
end

desc 'Notify Google of the new sitemap'
task :sitemap do
  begin
    %w(net/http uri).each{ |g| require g }
    puts '* Notifying Google'
    Net::HTTP.get('www.google.com', '/webmasters/tools/ping?sitemap=' + URI.escape("#{site_url}/sitemap.xml.gz"))
  rescue LoadError
    puts '! Could not ping Google (Net::HTTP or URI not found)'
  end
end

# TODO: pingomatic

desc 'Clean output directory and generated files'
task :clean do
  puts '* Cleaning'
  system("rm -rf #{site} css/*.css")
end

# TODO: create a new draft

# Helper methods
class Array
  # Converts the array to a comma-separated sentence where the last element is joined by the connector word. Options:
  # * <tt>:words_connector</tt> - The sign or word used to join the elements in arrays with two or more elements (default: ", ")
  # * <tt>:two_words_connector</tt> - The sign or word used to join the elements in arrays with two elements (default: " and ")
  # * <tt>:last_word_connector</tt> - The sign or word used to join the last element in arrays with three or more elements (default: ", and ")
  def to_sentence(options = {})
    default_words_connector = ", "
    default_two_words_connector = " and "
    default_last_word_connector = ", and "

    options.assert_valid_keys(:words_connector, :two_words_connector, :last_word_connector, :locale)
    options.reverse_merge! :words_connector => default_words_connector, :two_words_connector => default_two_words_connector, :last_word_connector => default_last_word_connector

    case length
      when 0
        ""
      when 1
        self[0].to_s
      when 2
        "#{self[0]}#{options[:two_words_connector]}#{self[1]}"
      else
        "#{self[0...-1].join(options[:words_connector])}#{options[:last_word_connector]}#{self[-1]}"
    end
  end
end

class Hash
  # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  # ==== Examples
  #   { :name => "Rob", :years => "28" }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key(s): years"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys("name", "age") # => raises "ArgumentError: Unknown key(s): name, age"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys(:name, :age) # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    unknown_keys = keys - [valid_keys].flatten
    raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
  end

  # Allows for reverse merging two hashes where the keys in the calling hash take precedence over those
  # in the <tt>other_hash</tt>. This is particularly useful for initializing an option hash with default values:
  #
  #   def setup(options = {})
  #     options.reverse_merge! :size => 25, :velocity => 10
  #   end
  #
  # Using <tt>merge</tt>, the above example would look as follows:
  #
  #   def setup(options = {})
  #     { :size => 25, :velocity => 10 }.merge(options)
  #   end
  #
  # The default <tt>:size</tt> and <tt>:velocity</tt> are only set if the +options+ hash passed in doesn't already
  # have the respective key.
  def reverse_merge(other_hash)
    other_hash.merge(self)
  end

  # Performs the opposite of <tt>merge</tt>, with the keys and values from the first hash taking precedence over the second.
  # Modifies the receiver in place.
  def reverse_merge!(other_hash)
    merge!(other_hash){|k, o, n| o}
  end
end

class String
  alias_method :starts_with?, :start_with?
  alias_method :ends_with?, :end_with?
end
