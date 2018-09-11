require 'find'
require 'yaml'
require 'livetext'

class RuneBlog
  VERSION = "0.0.56"

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
    dirs = subdirs("#@root/views/")
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

  def create_new_post(title, view=nil)
    view ||= @view
    date = Time.now.strftime("%Y-%m-%d")
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
    edit_initial_post(@fname)  # How eliminate for testing?
    process_post(@fname)  #- FIXME handle each view
    publish_post(@meta)
  rescue => err
    error(err)
  end

  def edit_initial_post(file)
    result = system("vi #@root/src/#{file} +8 ")
    raise "Problem editing #@root/src/#{file}" unless result
    nil
  rescue => err
    error(err)
  end

  def process_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
    path = @root + "/src/#{file}"
    @meta = @main.process_file(path, binding)
    raise "process_file returned nil" if @meta.nil?

    slug = self.make_slug(@meta.title, self.sequence)
    slug = file.sub(/.lt3$/, "")
    @meta.slug = slug
    @meta
  rescue => err
    error(err)
  end

  def publish_post(meta)
    puts "  #{colored_slug(meta.slug)}"
    # First gather the views
    views = meta.views
    print "       Views: "
    views.each do |view| 
      print "#{view} "
      link_post_view(view)
    end
#   assets = find_all_assets(@meta.assets, views)
    puts
  rescue => err
    error(err)
  end

  def link_post_view(view)
    # Create dir using slug (index.html, metadata?)
    vdir = self.viewdir(view)
    dir = vdir + @meta.slug + "/"
    create_dir(dir + "assets") 
    File.write("#{dir}/metadata.yaml", @meta.to_yaml)
    template = File.read(vdir + "custom/post_template.html")
    post = interpolate(template)
    File.write(dir + "index.html", post)
    generate_index(view)
  rescue => err
    error(err)
  end

  def generate_index(view)
    # Gather all posts, create list
    vdir = "#@root/views/#{view}"
    posts = Dir.entries(vdir).grep /^\d\d\d\d/
    posts = posts.sort.reverse

    # Add view header/trailer
    head = File.read("#{vdir}/custom/blog_header.html") rescue RuneBlog::BlogHeader
    tail = File.read("#{vdir}/custom/blog_trailer.html") rescue RuneBlog::BlogTrailer
    @bloghead = interpolate(head)
    @blogtail = interpolate(tail)

    # Output view
    posts.map! {|post| YAML.load(File.read("#{vdir}/#{post}/metadata.yaml")) }
    File.open("#{vdir}/index.html", "w") do |f|
      f.puts @bloghead
      posts.each {|post| f.puts posting(view, post) }
      f.puts @blogtail
    end
  rescue => err
    error(err)
  end

  def make_slug(title, seq=nil)
    num = '%04d' % (seq || self.next_sequence)   # FIXME can do better
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    "#{num}-#{slug}"
  end

  def subdirs(dir)
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  end
end
