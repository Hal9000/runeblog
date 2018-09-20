require 'find'
require 'yaml'
require 'livetext'

class RuneBlog
  VERSION = "0.0.63"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
  DefaultData = Path + "/../data"

  BlogHeaderPath  = DefaultData + "/custom/blog_header.html"
  BlogTrailerPath = DefaultData + "/custom/blog_trailer.html"
  BlogTemplatePath = DefaultData + "/custom/blog_trailer.html"

  BlogHeader  = File.read(BlogHeaderPath)  rescue "not found"
  BlogTrailer = File.read(BlogTrailerPath) rescue "not found"
  BlogTemplate = File.read(BlogTemplatePath) rescue "not found"

  attr_reader :root, :views, :sequence
  attr_accessor :view  # FIXME

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

  def create_view(arg)
    raise "view #{arg} already exists" if self.views.include?(arg)

    dir = @root + "/views/" + arg + "/"
    create_dir(dir + 'custom')
    create_dir(dir + 'assets')
    File.open(dir + "deploy", "w") { }  # FIXME

    File.write(dir + "custom/blog_header.html",  RuneBlog::BlogHeader)
    File.write(dir + "custom/blog_trailer.html", RuneBlog::BlogTrailer)
    File.write(dir + "custom/post_template.html", RuneBlog::BlogTemplate)
    File.write(dir + "last_deployed", "Initial creation")
    self.views << arg
  end

  def delete_view(name, force = false)
    if force
      system("rm -rf #@root/views/#{name}") 
      @views -= [name]
    end
  end

  def deployment_url
    return nil unless @deploy[@view]
    lines = @deploy[@view]
    user, server, sroot, spath = *@deploy[@view]
    url = "http://#{server}/#{spath}"
  end

  def view_files
    vdir = @blog.viewdir(@view)
    # meh
    files = ["#{vdir}/index.html"]
    files += Dir.entries(vdir).grep(/^\d\d\d\d/).map {|x| "#{vdir}/#{x}" }
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_deployed") }
  end

  def files_by_id(id)
    files = Find.find(self.root).to_a
    tag = "#{'%04d' % id}"
    result = files.grep(/#{tag}-/)
    result
  end

  def create_new_post(title, testing = false)
    view = @view
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
 
    num, @slug = make_slug(title)
    @fname = @slug + ".lt3"
    File.open("#@root/src/#@fname", "w") {|f| f.puts @template }
    edit_initial_post(@fname) unless testing
    process_post(@fname) #- FIXME handle each view
    publish_post(@meta)
    num
  rescue => err
    puts err # error(err)
  end

  def edit_initial_post(file)
    result = system("vi #@root/src/#{file} +8 ")
    raise "Problem editing #@root/src/#{file}" unless result
    nil
  rescue => err
    error(err)
  end

  def posts
    dir = self.viewdir(@view)
    posts = Dir.entries(dir).grep(/^0.*/)
  end

  def drafts
    dir = "#@root/src"
    drafts = Dir.entries(dir).grep(/^0.*.lt3/)
  end

  def change_view(view)
    @view = view
  end

  def process_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
    path = @root + "/src/#{file}"
    @meta = @main.process_file(path, binding)
    raise "process_file returned nil" if @meta.nil?

    num, slug = self.make_slug(@meta.title, self.sequence)
    slug = file.sub(/.lt3$/, "")
    @meta.slug = slug
    @meta
  rescue => err
    error(err)
  end

  def publish_post(meta)
    puts "  #{colored_slug(meta.slug)}" rescue nil  # puts(meta.slug)  # FIXME
    # First gather the views
    views = meta.views
    views.each {|view| link_post_view(view) }
#   assets = find_all_assets(@meta.assets, views)
    nil
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

  def relink
    self.views.each {|view| generate_index(view) }
  end

  def reload_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")  # FIXME srsly?
    @meta = process_post(file)
    @meta.slug = file.sub(/.lt3$/, "")
    @meta
  rescue => err
    error(err)
  end

  def posting(view, meta)
    # FIXME clean up and generalize
    ref = "#{view}/#{meta.slug}/index.html"
    <<-HTML
      <br>
      <font size=+1>#{meta.pubdate}&nbsp;&nbsp;</font>
      <font size=+2 color=blue><a href=../#{ref} style="text-decoration: none">#{meta.title}</font></a>
      <br>
      #{meta.teaser}  
      <a href=../#{ref} style="text-decoration: none">Read more...</a>
      <br><br>
      <hr>
    HTML
  end

  def rebuild_post(file)
    reload_post(file)
    publish_post(@meta)       # FIXME ??
  rescue => err
    error(err)
  end

  def remove_post(num)
    list = files_by_id(num)
    result = system("rm -rf #{list.join(' ')}")
    error_cant_delete(files) unless result
  end

  def post_exists?(num)
    list = files_by_id(num)
    list.empty? ? nil : list
  end

  def make_slug(title, postnum = nil)
    postnum ||= self.next_sequence
    num = '%04d' % postnum   # FIXME can do better
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    [postnum, "#{num}-#{slug}"]
  end

  def subdirs(dir)
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  end

  def create_dir(dir)
    cmd = "mkdir -p #{dir} >/dev/null 2>&1"
    result = system(cmd) 
    raise "Can't create #{dir}" unless result
  end

  def error(err)  # FIXME - this is duplicated
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace  # [0]
  end

  def interpolate(str)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def find_src_slugs
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files
  end

end
