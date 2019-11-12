require 'date'
require 'find'
require 'ostruct'

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

  def _tmp_error(err)   # FIXME move to helpers
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

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
    log!(enter: __method__, args: [root], level: 1)
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    root = Dir.pwd/root
    raise BlogRepoAlreadyExists if Dir.exist?(root)
    create_dirs(root)
    Dir.chdir(root) do
      create_dirs(:drafts, :views, :posts)
      new_sequence
    end
    x = OpenStruct.new
    x.root, x.current_view, x.editor = root, "test_view", "/usr/bin/vim "   # dumb - FIXME later
    write_config(x, root/ConfigFile)
    @blog = self.new(root)
    @blog
  rescue => err
    _tmp_error(err)
  end

  def self.open(root = ".blogs")
    log!(enter: __method__, args: [root])
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    root = Dir.pwd/root
    blog = self.new(root)
  rescue => err
    _tmp_error(err)
  end

  def initialize(root_dir = ".blogs")   # always assumes existing blog
    log!(enter: "initialize", args: [root_dir])
    # Crude - FIXME later -  # What views are there? Publishing, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?

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
    log!(enter: __method__, args: [dir], level: 1)
    Dir.chdir(dir) do
      views = _retrieve_metadata(:views)
      views.each do |v| 
        unless self.view?(v)
          puts "#{fx("Warning:", :red)} #{fx(v, :bold)} is not a view"
          next
        end
        system!("cp *html #@root/views/#{v}/remote", show: true)
      end
    end
  rescue => err
    _tmp_error(err)
  end

  def _retrieve_metadata(key)
    key = key.to_s
    lines = File.readlines("metadata.txt")
    lines = lines.grep(/^#{key}: /)
    case lines.size
      when 0
        result = nil  # not found
      when 1
        front = "#{key}: "
        n = front.size
        str = lines.first.chomp[n..-1]
        case key
          when "views", "tags"   # plurals
            result = str.split
        else
          result = str
        end
    else 
      raise "Too many #{key} instances in metadata.txt!"
    end
    return result
  rescue => err
    _tmp_error(err)
  end

  def process_post(sourcefile)
    log!(enter: __method__, args: [sourcefile], level: 2)
    nslug = sourcefile.sub(/.lt3/, "")
    dir = @root/:posts/nslug
    create_dirs(dir)
    # FIXME dependencies?
    xlate cwd: dir, src: @root/:drafts/sourcefile   # , debug: true
    _deploy_local(dir)
  rescue => err
    _tmp_error(err)
  end

  def inspect
    log!(enter: __method__, level: 3)
    str = "blog: "
    ivars = ["@root", "@sequence"]   # self.instance_variables
    ivars.each do |iv| 
      val = self.instance_variable_get(iv)
      str << "#{iv}: #{val}  "
    end
    str
  end

  def view?(name)
    log!(enter: __method__, args: [name], level: 3)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    views.any? {|x| x.name == name }
  end

  def view(name = nil)
    log!(enter: __method__, args: [name], level: 3)
    raise ArgumentError unless name.nil? || (name.is_a?(String) && ! name.empty?)
    name.nil? ? @view : str2view(name)
  end

  def str2view(str)
    log!(enter: __method__, args: [str], level: 3)
    raise ArgumentError unless str.is_a?(String) && ! str.empty?
    @views.find {|x| x.name == str }
  end

  def _set_publisher
    log!(enter: __method__, level: 3)
    @view.publisher = RuneBlog::Publishing.new(@view.to_s)  # FIXME refactor
  rescue => err
    _tmp_error(err)
  end

  def view=(arg)
    log!(enter: __method__, args: [arg], level: 2)
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
  rescue => err
    _tmp_error(err)
  end

  def get_sequence
    log!(enter: __method__, level: 3)
    File.read(@root/:sequence).to_i
  end

  def next_sequence
    log!(enter: __method__, level: 3)
    @sequence += 1
    dump(@sequence, @root/:sequence)
    @sequence
  end

  def viewdir(v = nil)   # delete?
    log!(enter: __method__, args: [v], level: 3)
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    v ||= @view
    return @root/:views/v
  end

  def self.exist?
    log!(enter: __method__, level: 3)
    Dir.exist?(DotDir) && File.exist?(DotDir/ConfigFile)
  end

  def mark_last_published(str)
    log!(enter: __method__, args: [str], level: 2)
    dump(str, "#{self.view.dir}/last_published")
  end

  def add_view(view_name)
    log!(enter: __method__, args: [view_name], level: 2)
    view = RuneBlog::View.new(view_name)
    @view = view    # current view
    @views << view  # all views
    view
  end

  def make_empty_view_tree(view_name)
    log!(enter: __method__, args: [view_name], level: 2)
    Dir.chdir(@root) do
      cmd = "cp -r #{RuneBlog::Path}/../empty_view views/#{view_name}"
      system!(cmd)
    end
  rescue => err
    _tmp_error(err)
  end

  def check_valid_new_view(view_name)
    log!(enter: __method__, args: [view_name], level: 3)
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
    log!(enter: __method__, args: [view_name], level: 2)
    check_valid_new_view(view_name)
    make_empty_view_tree(view_name)
    add_view(view_name)
    mark_last_published("Initial creation")
  rescue => err
    _tmp_error(err)
  end

  def delete_view(name, force = false)
    log!(enter: __method__, args: [name, force])
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    if force
      vname = @root/:views/name
      system!("rm -rf #{vname}")
      @views -= [str2view(name)]
    end
  end

  def view_files
    log!(enter: __method__, level: 2)
    vdir = self.view.dir
    files = [vdir/"index.html"]
    files += posts.map {|x| vdir/x }
    files.reject! {|f| File.mtime(f) < File.mtime(vdir/:last_published) }
  end

  def post_lookup(postid)    # side-effect?
    log!(enter: __method__, args: [postid], level: 2)
    slug = title = date = teaser_text = nil

    dir_posts = @vdir/:posts
    posts = Dir.entries(dir_posts).grep(/^\d\d\d\d/).map {|x| dir_posts/x }
    posts.select! {|x| File.directory?(x) }

    post = posts.select {|x| File.basename(x).to_i == postid }
    raise "Error: More than one post #{postid}" if post.size > 1
    postdir = post.first
    vp = RuneBlog::ViewPost.new(self.view, postdir)
    vp
  rescue => err
    _tmp_error(err)
  end

  def index_entry(slug)
    log!(enter: __method__, args: [slug], level: 2)
    id = slug.to_i
    text = nil
    @theme = @view.dir/"themes/standard"
    post_entry_name = @theme/"blog/post_entry.lt3"
# STDERR.puts "--  @pename = #{post_entry_name}"
# STDERR.puts "--  @pe = #{@_post_entry.inspect}"
    depend = [post_entry_name]
    xlate src: post_entry_name, dst: "/tmp/post_entry.html" # , deps: depend  # , debug: true
# STDERR.puts "-- xlate result: #{`ls -l /tmp/post_entry.html`}"
    @_post_entry ||= File.read("/tmp/post_entry.html")
    vp = post_lookup(id)
    nslug, aslug, title, date, teaser_text = 
      vp.nslug, vp.aslug, vp.title, vp.date, vp.teaser_text
    path = vp.path
    url = aslug + ".html"
    date = ::Date.parse(date)
    date = date.strftime("%B %e<br><div style='float: right'>%Y</div>")
    text = interpolate(@_post_entry, binding)
    text
  rescue => err
    _tmp_error(err)
  end

  def _sorted_posts
    posts = nil
    dir_posts = @vdir/:posts
    entries = Dir.entries(dir_posts)
    posts = entries.grep(/^\d\d\d\d/).map {|x| dir_posts/x }
    posts.select! {|x| File.directory?(x) }
    # directories that start with four digits
    posts = posts.sort do |a, b| 
      ai = a.index(/\d\d\d\d-/)
      bi = b.index(/\d\d\d\d-/)
      na = a[ai..(ai+3)].to_i
      nb = b[bi..(bi+3)].to_i
      nb <=> na
    end  # sort descending
    return posts[0..19]  # return 20 at most
  end

  def collect_recent_posts(file)
    log!(enter: __method__, args: [file], level: 3)
    text = <<-HTML
      <html>
      <head><link rel="stylesheet" href="etc/blog.css"></head>
      <body>
    HTML
    posts = _sorted_posts
STDERR.puts "Posts = "
posts.each {|x| STDERR.puts "  " + x }
    wanted = [8, posts.size].min  # estimate how many we want?
    enum = posts.each
    entries = []
    wanted.times do
      postid = File.basename(enum.next)
      postid = postid.to_i
# STDERR.puts "-- postid = #{postid}"
# posts.each {|x| STDERR.puts "    #{x}" }
      entry = index_entry(postid)
# STDERR.puts "--   entry = #{entry.size} chars"
      entries << entry
      text << entry
    end
    text << "</body></html>"
    File.write(@vdir/:remote/file, text)
  rescue => err
    _tmp_error(err)
  end

  def create_new_post(title, testing = false, teaser: nil, body: nil, 
                      pubdate: Time.now.strftime("%Y-%m-%d"), views: [])
    log!(enter: __method__, args: [title, testing, teaser, body, views], level: 1, stderr: true)
    meta = nil
    views = views + [self.view.to_s]
    views.uniq!
    Dir.chdir(@root/"posts") do
      post = Post.create(title: title, teaser: teaser, body: body, pubdate: pubdate, views: views)
      post.edit unless testing
      post.build
      meta = post.meta
    end
    return meta.num
  rescue => err
    _tmp_error(err)
  end

  def import_legacy_post(file, oldfile, testing = false)
  end

  def posts
    log!(enter: __method__, level: 3)
    dir = self.view.dir/:posts
    posts = Dir.entries(dir).grep(/^\d{4}/)
    posts
  end

  def drafts
    log!(enter: __method__, level: 3)
    dir = @root/:drafts
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
  end

  def change_view(view)
    log!(enter: __method__, args: [view], level: 3)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view.to_s, @editor   # dumb - FIXME later
    write_config(x, @root/ConfigFile)
    self.view = view   # error checking?
  end

  def generate_index(view)
    log!(enter: __method__, args: [view], pwd: true, dir: true)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    @vdir = @root/:views/view
    collect_recent_posts("recent.html")
  rescue => err
    _tmp_error(err)
  end

  def _hack_pinned_rebuild(view)
    tmp = "/tmp/pinned.lt3"
    File.open(tmp, "w") do |f|
      f.puts ".mixin liveblog\n.pinned_rebuild #{view}"
    end
    xlate src: tmp, dst: "/tmp/junk.html"
    system("rm -f #{tmp} /tmp/junk.html")
  end

  def generate_view(view)  # huh?
    log!(enter: __method__, args: [view])
    vdir = @root/:views/view
    @theme = @root/:views/view/:themes/:standard
    depend = [vdir/"remote/etc/blog.css", @theme/"global.lt3", 
             @theme/"blog/head.lt3", 
             # @theme/"navbar/navbar.lt3",
             @theme/"blog/index.lt3"]   # FIXME what about assets?
    xlate cwd: vdir/"themes/standard/etc", deps: depend,
          src: "blog.css.lt3", copy: vdir/"remote/etc/blog.css" # , debug: true
    xlate cwd: vdir/"themes/standard", deps: depend, force: true,
          src: "blog/generate.lt3", dst: vdir/:remote/"index.html"
    copy("#{vdir}/assets/*", "#{vdir}/remote/assets/")
#   _hack_pinned_rebuild(view)    # FIXME experimental
    copy_widget_html(view)
  rescue => err
    _tmp_error(err)
  end

  def _get_views(draft)
    log!(enter: __method__, args: [draft], level: 2)
    # FIXME dumb code
    view_line = File.readlines(draft).grep(/^.views /)
    raise "More than one .views call!" if view_line.size > 1
    raise "No .views call!" if view_line.size < 1
    view_line = view_line.first
    views = view_line[7..-1].split
    views.uniq 
  rescue => err
    _tmp_error(err)
  end

  def _copy_get_dirs(draft, view)
    log!(enter: __method__, args: [draft, view], level: 2)
    fname = File.basename(draft)
    noext = fname.sub(/.lt3$/, "")
    vdir = @root/:views/view
    dir = vdir/:posts/noext
    Dir.mkdir(dir) unless Dir.exist?(dir)
    system!("cp #{draft} #{dir}")
    viewdir, slugdir, aslug = vdir, dir, noext[5..-1]
    theme = viewdir/:themes/:standard
    [noext, viewdir, slugdir, aslug, theme]
  rescue => err
    _tmp_error(err)
  end

  def _post_metadata(draft, pdraft)
    log!(enter: __method__, args: [draft, pdraft], level: 2)
    # FIXME store this somewhere
    fname = File.basename(draft)       # 0001-this-is-a-post.lt3
    nslug = fname.sub(/.lt3$/, "")     # 0001-this-is-a-post
    aslug = nslug.sub(/\d\d\d\d-/, "") # this-is-a-post
    pnum = nslug[0..3]                 # 0001
    Dir.chdir(pdraft) do 
      excerpt = File.read("teaser.txt")
      date = _retrieve_metadata(:date)
      longdate = ::Date.parse(date).strftime("%B %e, %Y")
      title = _retrieve_metadata(:title)
      tags = _retrieve_metadata(:tags)
      # FIXME simplify
      vars = <<~LIVE
        .set post.num = #{pnum}
        .heredoc post.aslug
        #{aslug}
        .end
        .heredoc title
        #{title.chomp}
        .end
        .heredoc post.tags
        #{tags.join(" ")}
        .end
        .heredoc teaser
        #{excerpt.chomp}
        .end
        .heredoc longdate
        #{longdate}
        .end
      LIVE
      File.open(pdraft/"vars.lt3", "w") {|f| f.puts vars }
    end
  rescue => err
    _tmp_error(err)
  end

  def copy_widget_html(view)
    log!(enter: __method__, level: 2)
    vdir = @root/:views/view
    remote = vdir/:remote
    wdir = vdir/:themes/:standard/:widgets
    widgets = Dir[wdir/"*"].select {|w| File.directory?(w) }
    widgets.each do |w|
      dir = File.basename(w)
      rem = w.sub(/themes.standard/, "remote")
      create_dirs(rem)
      files = Dir[w/"*"]
      files = files.select {|x| x =~ /(html|css)$/ }
      tag = File.basename(w)
      files.each {|file| system!("cp #{file} #{rem}", show: (tag == "zzz")) }
    end
  rescue => err
    _tmp_error(err)
  end

  def _handle_post(draft, view_name = self.view.to_s)
    log!(enter: __method__, args: [draft, view_name], level: 2)
    # break into separate methods?

    fname = File.basename(draft)       # 0001-this-is-a-post.lt3
    nslug = fname.sub(/.lt3$/, "")     # 0001-this-is-a-post
    aslug = nslug.sub(/\d\d\d\d-/, "") # this-is-a-post
    ahtml = aslug + ".html"            # this-is-a-post.html
    pdraft = @root/:posts/nslug
    remote = @root/:views/view_name/:remote
    @theme = @root/:views/view_name/:themes/:standard
    # Step 1...
    create_dirs(pdraft)
    # FIXME dependencies?
    xlate cwd: pdraft, src: draft, dst: "guts.html"  # , debug: true
    _post_metadata(draft, pdraft)
    # Step 2...
    vposts = @root/:views/view_name/:posts
    copy!(pdraft, vposts)    # ??
    # Step 3..
    copy(pdraft/"guts.html", @theme/:post) 
    copy(pdraft/"vars.lt3",  @theme/:post) 
    # Step 4...
    # FIXME dependencies?
    xlate cwd: @theme/:post, src: "generate.lt3", force: true, 
          dst: remote/ahtml, copy: @theme/:post    # , debug: true
    # FIXME dependencies?
    xlate cwd: @theme/:post, src: "permalink.lt3", 
          dst: remote/:permalink/ahtml  # , debug: true
    copy_widget_html(view_name)
  rescue => err
    _tmp_error(err)
  end

  def generate_post(draft)
    log!(enter: __method__, args: [draft], level: 1)
    views = _get_views(draft)
    views.each do |view| 
      unless self.view?(view)
        puts "Warning: '#{view}' is not a view"
        next
      end
      _handle_post(draft, view)
    end
  rescue => err
    _tmp_error(err)
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
    _tmp_error(err)
  end

  def remove_post(num)
    log!(enter: __method__, args: [num], level: 1)
    raise ArgumentError unless num.is_a?(Integer)
    # FIXME update original draft .views
    tag = prefix(num)
    files = Find.find(self.view.dir).to_a
    list = files.select {|x| File.directory?(x) and x =~ /#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/(?<num>\d{4}-)/, "_\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system!(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def undelete_post(num)
    log!(enter: __method__, args: [num], level: 1)
    raise ArgumentError unless num.is_a?(Integer)
    files = Find.find(@root/:views).to_a
    tag = prefix(num)
    list = files.select {|x| File.directory?(x) and x =~ /_#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/_(?<num>\d{4}-)/, "\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system!(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def delete_draft(num)
    log!(enter: __method__, args: [num], level: 1)
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    system!("rm -rf #@root/drafts/#{tag}-*")
  end

  def make_slug(meta)
    log!(enter: __method__, args: [meta], level: 3)
    raise ArgumentError unless meta.title.is_a?(String)
    label = '%04d' % meta.num   # FIXME can do better
    slug0 = meta.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    str = "#{label}-#{slug0}"
    meta.slug = str
    str
  end
end

