require 'date'

require 'logging'

require 'runeblog_version'
require 'global'
require 'helpers-blog'
require 'default'
require 'view'
require 'publish'
require 'post'

require 'pathmagic'

###

class RuneBlog
 
  DotDir     = ".blogs"
  ConfigFile = "config"
  Themes     = RuneBlog::Path/"../themes"

  make_exception(:FileNotFound,          "File $1 was not found")
  make_exception(:BlogRepoAlreadyExists, "Blog repo $1 already exists")
  make_exception(:CantAssignView,        "$1 is not a view")
  make_exception(:ViewAlreadyExists,     "View $1 already exists")
  make_exception(:DirAlreadyExists,      "Directory $1 already exists")
  make_exception(:CantCreateDir,         "Can't create directory $1")
  make_exception(:EditorProblem,         "Could not edit $1")
  make_exception(:NoSuchView,            "No such view: $1")
  make_exception(:NoBlogAccessor,        "Runeblog.blog is not set")

  class << self
    attr_accessor :blog
    include Helpers
  end

  attr_reader :root, :views, :sequence, :editor
  attr_accessor :view  # overridden

  attr_accessor :post_views, :post_tags, :dirty_views

  include Helpers

  def self.create_new_blog_repo(dir = ".blogs")
    log!(enter: __method__, args: [dir])
    raise ArgumentError unless dir.is_a?(String) && ! dir.empty?
    root_dir = Dir.pwd/dir
    self.create(dir)
  rescue => err
    puts "Can't create blog repo: '#{dir}' - #{err}"
    puts err.backtrace.join("\n")
  end

  def self.create(root = ".blogs")
    log!(enter: __method__, args: [root])
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?
    root = Dir.pwd/root
    raise BlogRepoAlreadyExists if Dir.exist?(root)
    create_dirs(root)
    Dir.chdir(root) do
      system("cp #{RuneBlog::Path}/../empty_view.tgz .")
      create_dirs(:drafts, :views, :posts)
      new_sequence
    end
    put_config(root: root)
    @blog = self.new(root)
    @blog.create_view("test_view")
    @blog
  end

  def self.open(root = ".blogs")
    log!(enter: __method__, args: [root])
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?
    root = Dir.pwd/root
    blog = self.new(root)
  end

  def initialize(root_dir = ".blogs")   # always assumes existing blog
    log!(enter: "initialize", args: [root_dir])
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    $_blog = self            # Dumber still?

    @root = root_dir
    file = @root/ConfigFile
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

  def _deploy_local(dir)
    log!(enter: __method__, args: [dir])
    Dir.chdir(dir) do
      views = File.readlines("metadata.txt").grep(/^.views /).first[7..-1].split
      views.each {|v| system("cp *html #@root/views/#{v}/remote") }
    end
  end

  def process_post(sourcefile)
    log!(enter: __method__, args: [dir])
    nslug = sourcefile.sub(/.lt3/, "")
    dir = @root/:posts/nslug
    create_dir(dir)
    xlate cwd: dir, src: sourcefile, debug: true
    _deploy_local(dir)
  end

  def inspect
    log!(enter: __method__)
    str = "blog: "
    ivars = ["@root", "@sequence"]   # self.instance_variables
    ivars.each do |iv| 
      val = self.instance_variable_get(iv)
      str << "#{iv}: #{val}  "
    end
    str
  end

  def view?(name)
    log!(enter: __method__, args: [name])
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    views.any? {|x| x.name == name }
  end

  def view(name = nil)
    log!(enter: __method__, args: [name])
    raise ArgumentError unless name.nil? || (name.is_a?(String) && ! name.empty?)
    name.nil? ? @view : str2view(name)
  end

  def str2view(str)
    log!(enter: __method__, args: [str])
    raise ArgumentError unless str.is_a?(String) && ! str.empty?
    @views.find {|x| x.name == str }
  end

  def _set_publisher
    log!(enter: __method__)
    file = @view.dir/:publish
    @view.publisher = nil
    return unless File.exist?(file)
    @view.publisher = RuneBlog::Publishing.new(read_config(file))
  end

  def view=(arg)
    log!(enter: __method__, args: [arg])
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
    log!(enter: __method__)
    File.read(@root/:sequence).to_i
  end

  def next_sequence
    log!(enter: __method__)
    @sequence += 1
    dump(@sequence, @root/:sequence)
    @sequence
  end

  def viewdir(v = nil)   # delete?
    log!(enter: __method__, args: [v])
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    v ||= @view
    return @root/:views/v
  end

  def self.exist?
    log!(enter: __method__)
    Dir.exist?(DotDir) && File.exist?(DotDir/ConfigFile)
  end

  def make_dummy_publish_file(view_name)
    log!(enter: __method__, args: [view_name])
    vdir = @root/:views/view_name
    pub = [:user, :server, :docroot, :path, :proto]
    pub = pub.map {|x| x.to_s + ": undefined" }
    pub = pub.join("\n") + "\n"
    dump(pub, vdir/:publish)
  end

  def mark_last_published(str)
    log!(enter: __method__, args: [str])
    dump(str, "last_published")
  end

  def add_view(view_name)
    log!(enter: __method__, args: [view_name])
    view = RuneBlog::View.new(view_name)
    @view = view    # current view
    @views << view  # all views
    view
  end

  def make_empty_view_tree(view_name)
    log!(enter: __method__, args: [view_name])
    Dir.chdir(@root) do
      cmd1 = "tar zxvf empty_view.tgz >/dev/null 2>&1"
      cmd2 = "cp -r empty_view views/#{view_name}"
      system(cmd1)
      system(cmd2)
    end
  end

  def check_valid_new_view(view_name)
    log!(enter: __method__, args: [view_name])
    raise ArgumentError unless view_name.is_a?(String)
    raise ArgumentError if view_name.empty?
    names = self.views.map(&:to_s)
    bad = names.include?(view_name)
    raise ViewAlreadyExists(view_name) if bad
    vdir = @root/:views/view_name
    raise DirAlreadyExists(view_name) if Dir.exist?(vdir)
    return true   # hm?
  end

  def create_view(view_name)
    log!(enter: __method__, args: [view_name])
    check_valid_new_view(view_name)
    make_empty_view_tree(view_name)
    make_dummy_publish_file(view_name)
    mark_last_published("Initial creation")
    add_view(view_name)
  end

  def delete_view(name, force = false)
    log!(enter: __method__, args: [name, force])
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    if force
      vname = @root/:views/name
      system("rm -rf #{vname}")
      @views -= [str2view(name)]
    end
  end

  def view_files
    log!(enter: __method__)
    vdir = self.view.dir
    files = [vdir/"index.html"]
    files += posts.map {|x| vdir/x }
    files.reject! {|f| File.mtime(f) < File.mtime(vdir/:last_published) }
  end

  def post_lookup(postid)    # side-effect?
    log!(enter: __method__, args: [postid])
    slug = title = date = teaser_text = nil

    dir_posts = @vdir/:posts
    posts = Dir.entries(dir_posts).grep(/^\d\d\d\d/).map {|x| dir_posts/x }
    posts.select! {|x| File.directory?(x) }

    post = posts.select {|x| File.basename(x).to_i == postid }
    raise "Error: More than one post #{postid}" if post.size > 1
    postdir = post.first
    vp = RuneBlog::ViewPost.new(self.view, postdir)
    vp
  end

  def teaser(slug)
    log!(enter: __method__, args: [slug])
    id = slug.to_i
    text = nil
    post_entry_name = @theme/"blog/post_entry.lt3"
    @_post_entry ||= File.read(post_entry_name)
    vp = post_lookup(id)
    nslug, aslug, title, date, teaser_text = 
      vp.nslug, vp.aslug, vp.title, vp.date, vp.teaser_text
    path = vp.path
    url = aslug + ".html"
      date = ::Date.parse(date)
      date = date.strftime("%B %e<br>%Y")
      text = interpolate(@_post_entry, binding)
    text
  end

  def collect_recent_posts(file)
    log!(enter: __method__, args: [file])
    posts = nil
    dir_posts = @vdir/:posts
    entries = Dir.entries(dir_posts)
    posts = entries.grep(/^\d\d\d\d/).map {|x| dir_posts/x }
    posts.select! {|x| File.directory?(x) }
    # directories that start with four digits
    posts = posts.sort {|a, b| b.to_i <=> a.to_i }  # sort descending
    posts = posts[0..19]  # return 20 at most
    text = <<-HTML
      <html>
      <head><link rel="stylesheet" href="etc/blog.css"></head>
      <body>
    HTML
    wanted = [5, posts.size].min  # estimate how many we want?
    enum = posts.each
    wanted.times do
      postid = File.basename(enum.next)
      postid = postid.to_i
      text << teaser(postid)    # side effect! calls _out
    end
    text << "</body></html>"
    File.write(@vdir/:remote/file, text)
#    iframe_text = <<-HTML
#      <iframe name="main" style="width: 100vw;height: 100vh;position: relative;" 
#              src='recent.html' width=100% frameborder="0" allowfullscreen>
#      </iframe>
#    HTML
    # FIXME  ^ serves no purpose??
  end

  def create_new_post(title, testing = false, teaser: nil, body: nil, other_views: [])
    log!(enter: __method__, args: [title, testing, teaser, body, other_views])
    meta = nil
    Dir.chdir(@root/:posts) do
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
    log!(enter: __method__, args: [file, testing])
    debug "=== edit_initial_post #{file.inspect}  => #{sourcefile}"
    sourcefile = @root/:drafts/file
    result = system("#@editor #{sourcefile} +8") unless testing
    raise EditorProblem(sourcefile) unless result
    process_post(sourcefile)
    nil
  rescue => err
    error(err)
  end

  def posts
    log!(enter: __method__)
    dir = self.view.dir/:posts
    posts = Dir.entries(dir).grep(/^\d{4}/)
    posts
  end

  def drafts
    log!(enter: __method__)
    dir = @root/:drafts
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
  end

  def change_view(view)
    log!(enter: __method__, args: [view])
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view.to_s, @editor   # dumb - FIXME later
    write_config(x, ConfigFile)
    self.view = view   # error checking?
  end

  def generate_index(view) # FIXME  delete?
    log!(enter: __method__, args: [view], pwd: true, dir: true)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    @vdir = @root/:views/view
    collect_recent_posts("recent.html")
  end

  def generate_view(view)  # huh?
    log!(enter: __method__, args: [view])
    generate_index(view)   # recent posts (recent.html)
    vdir = @root/:views/view
    xlate cwd: vdir/:themes/:standard,
          src: "blog/generate.lt3", dst: vdir/:remote/"index.html"
  end

  def _get_views(draft)
    log!(enter: __method__, args: [draft])
    # FIXME dumb code
    view_line = File.readlines(draft).grep(/^.views /)
    raise "More than one .views call!" if view_line.size > 1
    raise "No .views call!" if view_line.size < 1
    view_line = view_line.first
    views = view_line[7..-1].split
    views 
  end

  def _copy_get_dirs(draft, view)
    log!(enter: __method__, args: [draft, view])
    fname = File.basename(draft)
    noext = fname.sub(/.lt3$/, "")
    vdir = @root/:views/view
    dir = vdir/:posts/noext
    Dir.mkdir(dir) unless Dir.exist?(dir)
    system("cp #{draft} #{dir}")
    viewdir, slugdir, aslug = vdir, dir, noext[5..-1]
    theme = viewdir/:themes/:standard
    [noext, viewdir, slugdir, aslug, theme]
  end

  def _post_metadata(draft, pdraft)
    log!(enter: __method__, args: [draft, pdraft])
    title_line = File.readlines(draft).grep(/^.title /).first
    title = title_line.split(" ", 2)[1]
#   pdir = "
    Dir.chdir(pdraft) do 
      excerpt = File.read("teaser.txt")
      vars = %[.set title="#{title.chomp}"\n] + 
             %[.set teaser="#{excerpt.chomp}"]
      File.open(pdraft/"vars.lt3", "w") {|f| f.puts vars }
    end
  end

  def copy_widget_html(view)
    log!(enter: __method__)
    vdir = @root/:views/view
    remote = vdir/:remote
    wdir = vdir/:themes/:standard/:widgets
    widgets = Dir[wdir/"*"].select {|w| File.directory?(w) }
    widgets.each do |w|
      dir = File.basename(w)
      rem = w.sub(/themes.standard/, "remote")
      create_dirs(rem)
      next unless Dir[w/"*"].any? {|x| x =~ /html$/ }
      system("cp #{w}/*html #{rem}")
    end
  end

  def _handle_post(draft, view)
    log!(enter: __method__, args: [draft, view])

    fname = File.basename(draft)       # 0001-this-is-a-post.lt3
    nslug = fname.sub(/.lt3$/, "")     # 0001-this-is-a-post
    aslug = nslug.sub(/\d\d\d\d-/, "") # this-is-a-post
    ahtml = aslug + ".html"            # this-is-a-post.html
    pdraft = @root/:posts/nslug
    remote = @root/:views/view/:remote
    @theme = @root/:views/view/:themes/:standard
    # Step 1...
    create_dirs(pdraft)
    xlate cwd: pdraft, src: draft, dst: "guts.html"
    _post_metadata(draft, pdraft)
    # Step 2...
    vposts = @root/:views/view/:posts
    copy!(pdraft, vposts)    # ??
    # Step 3..
    copy(pdraft/"guts.html", @theme/:post) 
    copy(pdraft/"vars.lt3",  @theme/:post) 
    # Step 4...
    xlate cwd: @theme/:post, src: "generate.lt3", 
          dst: remote/ahtml, copy: @theme/:post
    xlate cwd: @theme/:post, src: "permalink.lt3", 
          dst: remote/:permalink/ahtml
    copy_widget_html(view)
  end

  def generate_post(draft)
    log!(enter: __method__, args: [draft])
    views = _get_views(draft)
    views.each do |view| 
      _handle_post(draft, view)
      generate_view(view)
    end
  end

  def relink
    log!(enter: __method__)
    self.views.each {|view| generate_index(view) }
  end

  def index_entry(view, meta)
    log!(enter: __method__, args: [view, meta])
    debug "=== index_entry #{view.to_s.inspect}  #{meta.num} #{meta.title.inspect}"
    check_meta(meta, "index_entry1")
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    check_meta(meta, "index_entry2")
    self.make_slug(meta)
    check_meta(meta, "index_entry3")
    # FIXME clean up and generalize
    ref = view/meta.slug/"index.html"
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
    log!(enter: __method__, args: [file])
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
    log!(enter: __method__, args: [num])
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
    log!(enter: __method__, args: [num])
    raise ArgumentError unless num.is_a?(Integer)
    files = Find.find(@root/:views).to_a
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
    log!(enter: __method__, args: [num])
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    system("rm -rf #@root/drafts/#{tag}-*")
  end

  def make_slug(meta)
    log!(enter: __method__, args: [meta])
    raise ArgumentError unless meta.title.is_a?(String)
    label = '%04d' % meta.num   # FIXME can do better
    slug0 = meta.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    str = "#{label}-#{slug0}"
    meta.slug = str
    str
  end

end

