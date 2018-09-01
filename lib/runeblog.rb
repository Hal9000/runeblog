require 'find'
require 'yaml'
require 'livetext'

class RuneBlog
  VERSION = "0.0.50"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
  DefaultData = Path + "/../data"

  BlogHeaderPath  = DefaultData + "/custom/blog_header.html"
  BlogTrailerPath = DefaultData + "/custom/blog_trailer.html"

  BlogHeader  = File.read(BlogHeaderPath)  rescue "not found"
  BlogTrailer = File.read(BlogTrailerPath) rescue "not found"

  attr_reader :root, :views, :view, :sequence
  attr_writer :view  # FIXME

  def self.create_new_blog
    #-- what if data already exists?
    result = system("cp -r #{RuneBlog::DefaultData} .")
    raise "Error copying default data" unless result

    File.open(".blog", "w") do |f| 
      f.puts "data" 
      f.puts "no_default"
    end
    File.open("data/VERSION", "a") {|f| f.puts "\nBlog created: " + Time.now.to_s }
  end

  def initialize(cfg_file = ".blog")   # assumes existing blog
    # What views are there? Deployment, etc.
    # Crude - FIXME later

    lines = File.readlines(cfg_file).map {|x| x.chomp }
    @root = lines[0]
    @view = lines[1]
    dirs = Dir.entries("#@root/views/") - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    @root = root
    @views = dirs
    @sequence = File.read(root + "/sequence").to_i
  end

  def next_sequence
    @sequence += 1
    File.open("#@root/sequence", "w") {|f| f.puts @sequence }
    @sequence
  end

  def viewdir(v)
    @root + "/views/#{v}/"
  end

  def self.exist?
    File.exist?(".blog")
  end

  def create_new_post(title, date, view)
    @template = <<-EOS
.mixin liveblog
 
.title #{title}
.pubdate #{date}
.views #{view}
 
.teaser
Teaser goes here.
.end
Remainder of post goes here.
EOS
 
    @slug = make_slug(title)
    @fname = @slug + ".lt3"
    File.open("#@root/src/#@fname", "w") {|f| f.puts @template }
    @fname
  rescue => err
    error(err)
  end

  def make_slug(title, seq=nil)
    num = '%04d' % (seq || self.next_sequence)   # FIXME can do better
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    "#{num}-#{slug}"
  end

end
