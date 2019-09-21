require 'date'

require 'runeblog_version'
require 'global'
require 'helpers-blog'
require 'default'
require 'view'
require 'publish'
require 'post'

###

class RuneBlog
 
  DotDir     = ".blogs"
  ConfigFile = "config"
  Themes     = RuneBlog::Path + "/../themes"

  make_exception(:FileNotFound,      "File $1 was not found")
  make_exception(:BlogRepoAlreadyExists, "Blog repo $1 already exists")
  make_exception(:CantAssignView,    "$1 is not a view")
  make_exception(:ViewAlreadyExists, "View $1 already exists")
  make_exception(:DirAlreadyExists,  "Directory $1 already exists")
  make_exception(:CantCreateDir,     "Can't create directory $1")
  make_exception(:EditorProblem,     "Could not edit $1")
  make_exception(:NoSuchView,        "No such view: $1")
  make_exception(:NoBlogAccessor, "Runeblog.blog is not set")

  
  class << self
    attr_accessor :blog
    include Helpers
  end

  attr_reader :root, :views, :sequence, :editor
  attr_accessor :view  # overridden

  attr_accessor :post_views, :post_tags, :dirty_views

  include Helpers

  def self.create_new_blog_repo(dir = ".blogs")
    raise ArgumentError unless dir.is_a?(String) && ! dir.empty?
    root_dir = Dir.pwd + "/" + dir
    self.create(dir)
  rescue => err
    puts "Can't create blog repo: '#{dir}' - #{err}"
    puts err.backtrace.join("\n")
  end

  def self.create(root = ".blogs")
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?
    root = Dir.pwd + "/" + root
    raise BlogRepoAlreadyExists if Dir.exist?(root)
    create_dirs(root)
    Dir.chdir(root) do
      create_dirs(:drafts, :views)
      new_sequence
    end
    put_config(root: root)
    @blog = self.new(root)
    @blog.create_view("test_view")
    @blog
  end

  def self.open(root = ".blogs")
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?
    root = Dir.pwd + "/" + root
    blog = self.new(root)
  end

  def initialize(root_dir = ".blogs")   # always assumes existing blog
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?

    @root = root_dir
    file = @root + "/" + ConfigFile
    errmsg = "No config file! file = #{file.inspect}  dir = #{Dir.pwd}" 
    raise errmsg unless File.exist?(file)

    @root, @view_name, @editor = read_config(file, :root, :current_view, :editor)
    md = Dir.pwd.match(%r[.*/views/(.*?)/])
    @view_name = md[1] if md
    @views = get_views
    @view = str2view(@view_name)
    @sequence = get_sequence
    @post_views = []
    @post_tags = []
  end

  def inspect
    str = "[["
    ivars = ["@root", "@sequence"]   # self.instance_variables
    ivars.each do |iv| 
      val = self.instance_variable_get(iv)
      str << "#{iv} = #{val}  "
    end
    str << "]]"
    str
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

  def _set_publisher
    file = @view.dir + "/publish"
    @view.publisher = nil
    return unless File.exist?(file)
    @view.publisher = RuneBlog::Publishing.new(read_config(file))
  end

  def view=(arg)
    case arg
      when RuneBlog::View
        @view = arg
        _set_publisher
      when String
        new_view = str2view(arg)
        raise NoSuchView(arg) if new_view.nil?
        @view = new_view
        _set_publisher
      else 
        raise CantAssignView(arg.class.to_s)
    end
  end

  def get_sequence
    File.read(root + "/sequence").to_i
  end

  def next_sequence
    @sequence += 1
    dump(@sequence, "#@root/sequence")
    @sequence
  end

  def viewdir(v = nil)   # delete?
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    v ||= @view
    @root + "/views/#{v}/"
  end

  def self.exist?
    Dir.exist?(DotDir) && File.exist?(DotDir + "/" + ConfigFile)
  end

  def create_view(arg)
    raise ArgumentError unless arg.is_a?(String) && ! arg.empty?

    names = self.views.map(&:to_s)
    raise ViewAlreadyExists(arg) if names.include?(arg)

    vdir = "#@root/views/#{arg}/"
    raise DirAlreadyExists(vdir) if Dir.exist?(vdir)
    create_dirs(vdir)
    up = Dir.pwd

    Dir.chdir(vdir) do
      x = RuneBlog::Default
      copy!("#{Themes}", "themes")
      create_dirs(:assets, :posts)
      create_dirs(:staging, "remote/permalink", "remote/navbar")
      livetext "themes/standard/etc/blog.css.lt3" # strip ext
      copy!("themes/standard/*", "staging/")

      copy!("themes/standard/etc", "remote/")
      copy!("themes/standard/assets", "remote/")
      copy!("themes/standard/widgets", "remote/")

      pub = "user: xxx\nserver: xxx\ndocroot: xxx\npath: xxx\nproto: xxx\n"
      dump(pub, "publish")

      view = RuneBlog::View.new(arg)
      self.view = view
      vdir = self.view.dir
      dump("Initial creation", "last_published")
    end  
    @views << view
    @views
  end

  def delete_view(name, force = false)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    if force
      system("rm -rf #@root/views/#{name}") 
      @views -= [str2view(name)]
    end
  end

  def view_files
    vdir = self.view.dir
    files = ["#{vdir}/index.html"]
    files += posts.map {|x| "#{vdir}/#{x}" }
    # Huh? 
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_published") }
  end

  def post_lookup(postid)    # side-effect?
    # .. = templates, ../.. = views/thisview
    slug = title = date = teaser_text = nil

    dir_posts = @vdir + "/posts"
    posts = Dir.entries(dir_posts).grep(/^\d\d\d\d/).map {|x| dir_posts + "/" + x }
    posts.select! {|x| File.directory?(x) }

    post = posts.select {|x| File.basename(x).to_i == postid }
    raise "Error: More than one post #{postid}" if post.size > 1
    postdir = post.first
    vp = RuneBlog::ViewPost.new(self.view, postdir)
    vp
  end

  def teaser(slug)
    id = slug.to_i
    text = nil
    post_entry_name = @theme + "/blog/post_entry.lt3"
    @_post_entry ||= File.read(post_entry_name)
    vp = post_lookup(id)
    nslug, aslug, title, date, teaser_text = 
      vp.nslug, vp.aslug, vp.title, vp.date, vp.teaser_text
    path = vp.path
#   url = "#{path}/#{aslug}.html"    # Should be relative to .blogs!! FIXME
    url = "#{aslug}.html"    # Should be relative to .blogs!! FIXME
      date = ::Date.parse(date)
      date = date.strftime("%B %e<br>%Y")
      text = interpolate(@_post_entry, binding)
    text
  end

  def collect_recent_posts(file)
    @vdir = ".."
    posts = nil
    dir_posts = @vdir + "/posts"
    entries = Dir.entries(dir_posts)
    posts = entries.grep(/^\d\d\d\d/).map {|x| dir_posts + "/" + x }
    posts.select! {|x| File.directory?(x) }
    # directories that start with four digits
    posts = posts.sort {|a, b| b.to_i <=> a.to_i }  # sort descending
    posts = posts[0..19]  # return 20 at most
    text = <<-HTML
      <html>
      <head><link rel="stylesheet" href="etc/blog.css"></head>
      <body>
    HTML
    # posts = _find_recent_posts
    wanted = [5, posts.size].min  # estimate how many we want?
    enum = posts.each
    wanted.times do
      postid = File.basename(enum.next)
      postid = postid.to_i
      text << teaser(postid)    # side effect! calls _out
    end
    text << "</body></html>"
    File.write(file, text) # FIXME ???
    iframe_text = <<-HTML
      <iframe name="main" style="width: 100vw;height: 100vh;position: relative;" 
              src='recent.html' width=100% frameborder="0" allowfullscreen>
      </iframe>
    HTML
  end

  def create_new_post(title, testing = false, teaser: nil, body: nil, other_views: [])
    meta = nil
    Dir.chdir(self.view.dir) do
      post = Post.create(title: title, teaser: teaser, body: body, other_views: other_views)
      post.edit unless testing
      post.build
      meta = post.meta
    end
    return meta.num
  rescue => err
    puts err
    puts err.backtrace.join("\n")
  end

  def edit_initial_post(file, testing = false)
    debug "=== edit_initial_post #{file.inspect}  => #{sourcefile}"
    sourcefile = "#@root/drafts/#{file}"
    result = system("#@editor #{sourcefile} +8") unless testing
    raise EditorProblem(sourcefile) unless result
    nil
  rescue => err
    error(err)
  end

  def posts
    dir = self.view.dir + "/posts"
    posts = Dir.entries(dir).grep(/^\d{4}/)
    posts
  end

  def drafts
    dir = "#@root/drafts"
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
  end

  def change_view(view)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view.to_s, @editor   # dumb - FIXME later
    write_config(x, ConfigFile)
    self.view = view   # error checking?
  end

  def generate_index(view) # FIXME  delete?
    debug "=== generate_index view = #{view.to_s}"
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)

    vdir = self.view.dir
    dir0 = "#{vdir}/themes/standard/blog"
  rescue => err
    error(err)
    exit
  end

  def generate_view(view)  # huh?
  end

  def _get_views(draft)
    # FIXME dumb code
    view_line = File.readlines(draft).grep(/^.views /)
    raise "More than one .views call!" if view_line.size > 1
    raise "No .views call!" if view_line.size < 1
    view_line = view_line.first
    views = view_line[7..-1].split
    views 
  end

  # Remember: A post in multiple views will trigger multiple
  #   views needing to be rebuilt (and published)

  # generate a post:
  #   given draft 9999-title.lt3
  #   create VIEW/posts/9999-title/index.lt3
  # LATER: metadata!! or is it in head?
  #   Generate VIEW/posts/9999-title/head.lt3?
  #   livetext draft_wrapper_plain.lt3  >generated/posts/plain-title.html  # unframed
  #   livetext draft_generate.lt3       >generated/posts/real-title.html   # framed
  #   livetext draft_wrapper_perma.lt3  >generated/posts/perma-title.html  # permaframed
  #
  # Generate associated views:
  #   livetext ??/recent.lt3 >VIEW/working/recent.html
  #   livetext VIEW/blog/generate.lt3 ??

  def _copy_get_dirs(draft, view)
    fname = File.basename(draft)
    noext = fname.sub(/.lt3$/, "")
    vdir = "#@root/views/#{view}"
    dir = "#{vdir}/posts/#{noext}/"
    Dir.mkdir(dir) unless Dir.exist?(dir)
    system("cp #{draft} #{dir}")
    viewdir, slugdir, aslug = vdir, dir, noext[5..-1]
    theme = viewdir + "/themes/standard"
    [noext, viewdir, slugdir, aslug, theme]
  end

  def generate_post(draft)
    views = _get_views(draft)
    views.each do |view|
      noext, viewdir, slugdir, aslug, @theme = _copy_get_dirs(draft, view)
      staging = viewdir + "/staging"
      Dir.chdir(slugdir) do 
        copy(draft, ".")
        lt3 = draft.split("/")[-1]
        # Remember: Some posts may be in more than one view -- careful with links back
        # system("livetext #{draft} >staging/#{name}/index.html")  # permalink?
        copy!("#{@theme}/*", "#{staging}")
        copy(lt3, staging)
        html = noext[5..-1]
        livetext draft, html  # livetext "foobar.lt3", "foobar.html"
        copy(html, "../../staging/post/index.html")
        title_line = File.readlines(draft).grep(/^.title /).first
        title = title_line.split(" ", 2)[1]
        excerpt = File.read("teaser.txt")
        vars = %[.set title="#{title.chomp}"\n] + 
               %[.set teaser="#{excerpt.chomp}"]
        Dir.chdir(staging) do 
          File.open("vars.lt3", "w") {|f| f.puts vars }
          livetext "post/generate.lt3", html
          copy html, "../remote"
          livetext "post/permalink.lt3", "../remote/permalink/#{html}"
          collect_recent_posts("recent.html")
          copy("recent.html", "../remote")
          copy!("navbar/*html", "../remote/navbar/")
          copy!("widgets", "../remote/")  # really copies too much...
          livetext "blog/generate",  "../remote/index"
        end
      end
    end
  end

  def relink
    self.views.each {|view| generate_index(view) }
  end

  def index_entry(view, meta)
    debug "=== index_entry #{view.to_s.inspect}  #{meta.num} #{meta.title.inspect}"
    check_meta(meta, "index_entry1")
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    check_meta(meta, "index_entry2")
    self.make_slug(meta)
    check_meta(meta, "index_entry3")
    # FIXME clean up and generalize
    ref = "#{view}/#{meta.slug}/index.html"
    <<-HTML
      <font size=-1>#{meta.date}&nbsp;&nbsp;</font> <br>
      <font size=+2 color=blue><a href=../#{ref} style="text-decoration: none">#{meta.title}</font></a>
      <br>
      <font size=+1>#{meta.teaser}&nbsp;&nbsp;</font>
      <a href=../#{ref} style="text-decoration: none">Read more...</a>
      <br>
      <hr>
    HTML
  end

  def rebuild_post(file)
    raise "Doesn't currently work"
    debug "Called rebuild_post(#{file.inspect})"
    raise ArgumentError unless file.is_a?(String)
    meta = process_post(file)
    @views_dirty ||= []
    @views_dirty << meta.views
    @views_dirty.flatten!
    @views_dirty.uniq!
  rescue => err
    error(err)
    getch
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
    system("rm -rf #@root/drafts/#{tag}-*")
  end

  def make_slug(meta)
    raise ArgumentError unless meta.title.is_a?(String)
    label = '%04d' % meta.num   # FIXME can do better
    slug0 = meta.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    str = "#{label}-#{slug0}"
    meta.slug = str
    str
  end

end

