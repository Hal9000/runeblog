require 'find'
require 'livetext'
require 'global'
require 'helpers-blog'
require 'default'
require 'view'
require 'publish'
require 'post'
require 'version'


###

class RuneBlog
 
  DotDir = ".blog"
  ConfigFile = "#{DotDir}/config"

  make_exception(:FileNotFound,      "File $1 was not found")
  make_exception(:BlogAlreadyExists, "Blog $1 already exists")
  make_exception(:CantAssignView,    "$1 is not a view")
  make_exception(:ViewAlreadyExists, "View $1 already exists")
  make_exception(:DirAlreadyExists,  "Directory $1 already exists")
  make_exception(:CantCreateDir,     "Can't create directory $1")
  make_exception(:EditorProblem,     "Could not edit $1")
  make_exception(:NoSuchView,        "No such view: $1")
  make_exception(:LivetextError,     "Livetext#process_file returned nil for $1")
  
  class << self
    attr_accessor :blog
    include Helpers
  end

  attr_reader :root, :views, :sequence, :editor
  attr_accessor :view  # overridden

  include Helpers

  def self.create_new_blog(dir = ".blog")
    raise ArgumentError unless dir.is_a?(String) && ! dir.empty?
    root_dir = Dir.pwd + "/" + dir
    raise BlogAlreadyExists if Dir.exist?(root_dir)
    new_dotfile(root: root_dir, current_view: "test_view")
    create_dir(dir)
    Dir.chdir(dir) do
      create_dir("views")
      create_dir("assets")
      create_dir("src")
      new_sequence
    end
    blog = self.new
    blog.create_view("test_view")
  rescue => err
    puts "Can't create blog: '#{dir}' - #{err}"  # CHANGE_FOR_CURSES?
    puts err.backtrace  # CHANGE_FOR_CURSES?
  end

  def initialize   # assumes existing blog
    # Crude - FIXME later - 
    # What views are there? Publishing, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    @root, @view_name, @editor = 
      read_config(ConfigFile, :root, :current_view, :editor)
    @views = get_views
    @view = str2view(@view_name)
    @sequence = get_sequence
  end

  def view?(name)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    views.any? {|x| x.name == name }
  end

  def view(name = nil)
    raise ArgumentError unless name.nil? || (name.is_a?(String) && ! name.empty?)
    name.nil? ? @view : str2view(name)
  end

  def str2view(str)
    raise ArgumentError unless str.is_a?(String) && ! str.empty?
    @views.find {|x| x.name == str }
  end

  def view=(arg)
    case arg
      when RuneBlog::View
        @view = arg
        @view.publisher = read_config(@view.dir + "/publish")
      when String
        new_view = str2view(arg)
        raise NoSuchView(arg) if new_view.nil?
        @view = new_view
        @view.publisher = read_config(@view.dir + "/publish")
      else 
        raise CantAssignView(arg.class.to_s)
    end
  end

  def get_sequence
    File.read(root + "/sequence").to_i
  end

  def next_sequence
    dump(@sequence += 1, "#@root/sequence")
    @sequence
  end

  def viewdir(v = nil)
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    v ||= @view
    @root + "/views/#{v}/"
  end

  def self.exist?
    Dir.exist?(DotDir) && File.exist?(ConfigFile)
  end

  def create_view(arg)
    raise ArgumentError unless arg.is_a?(String) && ! arg.empty?
    names = self.views.map(&:to_s)
    raise ViewAlreadyExists(arg) if names.include?(arg)

    dir = "#@root/views/#{arg}/"
    raise DirAlreadyExists(dir) if Dir.exist?(dir)
    create_dir(dir)
    up = Dir.pwd
    Dir.chdir(dir)
    x = RuneBlog::Default
    create_dir('custom')
    create_dir('assets')
    # FIXME dump method??
    dump("", "publish")
    dump(x::BlogHeader, "custom/blog_header.html")
    dump(x::BlogTrailer, "custom/blog_trailer.html")
    dump(x::PostTemplate, "custom/post_template.html")
    dump("Initial creation", "last_published")
    Dir.chdir(up)
    @views << RuneBlog::View.new(arg)
  end

  def delete_view(name, force = false)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    if force
      system("rm -rf #@root/views/#{name}") 
      @views -= [str2view(name)]
    end
  end

  def view_files
    vdir = @blog.viewdir
    files = ["#{vdir}/index.html"]
    files += posts.map {|x| "#{vdir}/#{x}" }
    # Huh? 
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_published") }
  end

  def files_by_id(id)   # FIXME get rid of this later
    raise ArgumentError unless id.is_a?(Integer)
    files = Find.find(self.view.dir).to_a
    tag = prefix(id)
    result = files.grep(/#{tag}-/)
    result
  end

# def create_new_post(title, testing = false, teaser = nil, body = nil)
  def create_new_post(meta, testing = false)
    meta.teaser ||= "Teaser goes here."
    meta.body ||= "Remainder of post goes here."
    post = RuneBlog::Post.new(meta, @view.to_s)
    post.edit unless testing
    post.build
    post.num
  rescue => err
    puts err # error(err)  # CHANGE_FOR_CURSES?
  end

  def edit_initial_post(file, testing = false)
    sourcefile = "#@root/src/#{file}"
    result = system("#@editor #{sourcefile} +8") unless testing
    raise EditorProblem(sourcefile) unless result
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
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view.to_s, @editor   # dumb - FIXME later
    write_config(x, ConfigFile)
    self.view = view   # error checking?
  end

  def process_post(file)
    raise ArgumentError unless file.is_a?(String)
    path = @root + "/src/#{file}"
    raise FileNotFound(path) unless File.exist?(path)
    livetext = Livetext.new(STDOUT) # (nil)
    @meta = livetext.process_file(path, binding)
    raise LivetextError(path) if @meta.nil?

    num, slug = self.make_slug(@meta.title, self.sequence)
    slug = file.sub(/.lt3$/, "")
    @meta.slug = slug
    @meta
  rescue => err
    error(err)
  end

  def build_post_view(view)
    # Create dir using slug (index.html, metadata?)
    vdir = self.viewdir(view) # FIXME
    dir = vdir + @meta.slug + "/"
    create_dir(dir + "assets") 
    Dir.chdir(dir) do
      dump(@meta.teaser, "teaser.txt")
      dump(@meta.body, "body.txt")
      # FIXME make get_post_template method
      template = File.read("#{vdir}/custom/post_template.html")
      post = interpolate(template)
      dump(post, "index.html")
    end
    generate_index(view)
  rescue => err
    error(err)
  end

  def generate_index(view)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
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
    posts.map! do |post|
      meta = nil
      pdir = vdir + "/" + post
      Dir.chdir(pdir) do
        meta = read_config("metadata.txt")
        meta.teaser = File.read("teaser.txt")
        meta.body = File.read("body.txt")
      end
      meta  # block return
    end
    File.open("#{vdir}/index.html", "w") do |f|
      f.puts @bloghead
      posts.each {|post| f.puts index_entry(view, post) }
      f.puts @blogtail
    end
  rescue => err
    error(err)
    exit
  end

  def relink
    self.views.each {|view| generate_index(view) }
  end

  def index_entry(view, meta)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    meta.slug ||= make_slug(meta.title)
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
    raise ArgumentError unless file.is_a?(String)
    @meta = process_post(file)
    @meta.views.each do |view| 
      build_post_view(view)
    end
  rescue => err
    error(err)
  end

  def remove_post(num)
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    files = Find.find(self.view.dir).to_a
    list = files.select {|x| File.directory?(x) and x =~ /#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/(?<num>\d{4}-)/, "_\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def undelete_post(num)
    raise ArgumentError unless num.is_a?(Integer)
    files = Find.find("#@root/views/").to_a
    tag = prefix(num)
    list = files.select {|x| File.directory?(x) and x =~ /_#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/_(?<num>\d{4}-)/, "\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def delete_draft(num)
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    system("rm -rf #@root/src/#{tag}-*")
  end

  def post_exists?(num)
    raise ArgumentError unless num.is_a?(Integer)
    list = files_by_id(num)  # FIXME search under view dirs
    list.empty? ? nil : list
  end

  def make_slug(title, postnum = nil)
    raise ArgumentError unless title.is_a?(String)
    postnum ||= self.next_sequence
    num = '%04d' % postnum   # FIXME can do better
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    [postnum, "#{num}-#{slug}"]
  end

end

