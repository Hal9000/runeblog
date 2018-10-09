require 'pp'

require 'find'
require 'yaml'   # get rid of YAML later
require 'livetext'
require 'skeleton'
require 'helpers-blog'
require 'default'
require 'view'
require 'deploy'
require 'post'
require 'version'

###

class RuneBlog

  class << self
    attr_accessor :blog
  end

  attr_reader :root, :views, :sequence
  attr_accessor :view  # overridden

  def self.create_new_blog(dir = "data")
    x = OpenStruct.new
    x.root, x.current_view, x.editor = dir, "no_default", "vi"
    write_config(x, ".blog")
    create_dir(dir)
    Dir.chdir(dir) do
      create_dir("views")
      create_dir("assets")
      create_dir("src")
      File.write("sequence", 0)
      File.write("VERSION", "#{RuneBlog::VERSION}\nBlog created: " + Time.now.to_s )
    end
  end

  def initialize(cfg_file = ".blog")   # assumes existing blog
    # Crude - FIXME later - What views are there? Deployment, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    obj = read_config(cfg_file)
    vals = obj.to_h.values_at(:root, :current_view, :editor)
    @root, view_name, @editor = *vals
    @views = subdirs("#@root/views/").sort.map {|name| RuneBlog::View.new(name) }
    @view = str2view(view_name)
    @sequence = get_sequence
  end

  def view?(name)
    views.any? {|x| x.name == name }
  end

  def view(name = nil)
    name.nil? ? @view : str2view(name)
  end

  def str2view(str)
    @views.find {|x| x.name == str }
  end

  def view=(arg)
    case arg
      when RuneBlog::View
        @view = arg
        raise "Problem here?"
        @view.read_config
      when String
        new_view = str2view(arg)
        raise "Can't find view #{arg}" if new_view.nil?
        @view = new_view
        @view.deployer = read_config(@view.dir + "/deploy")
      else 
        raise "#{arg.inspect} was not a View or a String"
    end
  end

  def get_sequence
    File.read(root + "/sequence").to_i
  end

  def next_sequence
    File.write("#@root/sequence", @sequence += 1)
    @sequence
  end

  def viewdir(v)
    @root + "/views/#{v}/"
  end

  def self.exist?
    File.exist?(".blog")
  end

  def create_view(arg)
    names = self.views.map(&:to_s)
    raise "view #{arg} already exists" if names.include?(arg)

    dir = "#@root/views/#{arg}/"
    create_dir(dir)
    up = Dir.pwd
    Dir.chdir(dir)
    create_dir('custom')
    create_dir('assets')
    File.write("deploy", "")
    File.write("custom/blog_header.html",  
               RuneBlog::Default::BlogHeader)
    File.write("custom/blog_trailer.html", 
               RuneBlog::Default::BlogTrailer)
    File.write("custom/post_template.html", 
               RuneBlog::Default::PostTemplate)
    File.write("last_deployed", 
               "Initial creation")
    Dir.chdir(up)
    @views << RuneBlog::View.new(arg)
  end

  def delete_view(name, force = false)
    if force
      system("rm -rf #@root/views/#{name}") 
      @views -= [str2view(name)]
    end
  end

  def view_files
    vdir = @blog.viewdir(@view)
    # meh
    files = ["#{vdir}/index.html"]
    files += Dir.entries(vdir).grep(/^\d{4}/).map {|x| "#{vdir}/#{x}" }
    # Huh? 
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_deployed") }
  end

  def files_by_id(id)
    files = Find.find(self.view.dir).to_a
    tag = "#{'%04d' % id}"
    result = files.grep(/#{tag}-/)
    result
  end

# def create_new_post(title, testing = false, teaser = nil, remainder = nil)
  def create_new_post(meta, testing = false)
    meta.teaser ||= "Teaser goes here."
    meta.remainder ||= "Remainder of post goes here."
    post = RuneBlog::Post.new(meta, @view.to_s)
    post.edit unless testing
    post.publish
    post.num
  rescue => err
    puts err # error(err)
  end

  def edit_initial_post(file)
    result = system("#@editor #@root/src/#{file} +8")
    raise "Problem editing #@root/src/#{file}" unless result
    nil
  rescue => err
    error(err)
  end

  def posts
    dir = self.view.dir
    posts = Dir.entries(dir).grep(/^\d{4}/)
    posts
  end

  def drafts
    dir = "#@root/src"
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
  end

  def change_view(view)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view, @editor   # dumb - FIXME later
    write_config(x, ".blog")
    self.view = view   # error checking?
  end

  def process_post(file)
    path = @root + "/src/#{file}"
    livetext = Livetext.new(STDOUT) # (nil)
    @meta = livetext.process_file(path, binding)
    raise "process_file returned nil" if @meta.nil?

    num, slug = self.make_slug(@meta.title, self.sequence)
    slug = file.sub(/.lt3$/, "")
    @meta.slug = slug
    @meta
  rescue => err
    error(err)
  end

  def publish_post(meta)
    meta.views.each {|view| link_post_view(view) }
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
    posts = Dir.entries(vdir).grep /^\d{4}/
    posts = posts.sort.reverse

    # Add view header/trailer
    head = tail = nil
    Dir.chdir(vdir) do 
      head = File.read("custom/blog_header.html")
      tail = File.read("custom/blog_trailer.html")
    end
    @bloghead = interpolate(head)
    @blogtail = interpolate(tail)

    # Output view
    posts.map! {|post| YAML.load(File.read("#{vdir}/#{post}/metadata.yaml")) }
    File.open("#{vdir}/index.html", "w") do |f|
      f.puts @bloghead
      posts.each {|post| f.puts index_entry(view, post) }
      f.puts @blogtail
    end
  rescue => err
    error(err)
  end

  def relink
    self.views.each {|view| generate_index(view) }
  end

  def index_entry(view, meta)
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
    @meta = process_post(file)
    publish_post(@meta)       # FIXME ??
  rescue => err
    error(err)
  end

  def remove_post(num)
    list = files_by_id(num)
    return nil if list.empty?
    dest = list.map {|f| f.sub(/(?<num>\d{4}-)/, "_\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def delete_draft(num)
    tag = "#{'%04d' % num.to_i}"
    system("rm -rf #@root/src/#{tag}-*")
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

  private

  def subdirs(dir)
raise Exception.new("hell") if dir == "/views/"
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  rescue => err
    p err
  end

  def find_src_slugs
    files = Dir.entries("#@root/src/").grep /\d{4}.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files
  end

  def create_dir(dir)
    return if File.exist?(dir) && File.directory?(dir)
    cmd = "mkdir -p #{dir} >/dev/null 2>&1"
    result = system(cmd) 
    raise "Can't create #{dir}" unless result
  end

  def interpolate(str)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def error(err)  # Hmm, this is duplicated
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace
  end

end

