if ! defined?(Already_runeblog)

  Already_runeblog = nil

require 'date'
require 'find'
require 'ostruct'

require 'logging'

require 'runeblog_version'
require 'helpers-blog'
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

  attr_reader :views, :sequence
  attr_accessor :root, :editor
  attr_accessor :view  # overridden

  attr_accessor :post_views, :post_tags, :dirty_views

  include Helpers

    class Default

    # This will all become much more generic later.

    def RuneBlog.post_template(num: 0, title: "No title", date: nil, view: "test_view", 
                               teaser: "No teaser", body: "No body", tags: ["untagged"], 
                               views: [], back: "javascript:history.go(-1)", home: "no url")
      log!(enter: __method__, args: [num, title, date, view, teaser, body, tags, views, back, home], level: 3)
      viewlist = (views + [view.to_s]).join(" ")
      taglist = ".tags " + tags.join(" ")

      <<~TEXT
      .post #{num}

      .title #{title}
      .pubdate #{date}
      .views #{viewlist}
      #{taglist}

      .teaser
      #{teaser}
      .end
      #{body}
      TEXT
    end

  end

  def _tmp_error(err)   # FIXME move to helpers
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def self.create_new_blog_repo(root_rel = ".blogs")
    log!(enter: __method__, args: [root_rel])
    raise ArgumentError unless root_rel.is_a?(String) && ! root_rel.empty?
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    repo_root = Dir.pwd/root_rel
    raise BlogRepoAlreadyExists if Dir.exist?(repo_root)
    create_dirs(repo_root)
    Dir.chdir(repo_root) do
      create_dirs(:data, :config, :drafts, :views, :posts)
      new_sequence
    end
    unless File.exist?(repo_root/"data/VIEW")
      copy_data(:config, repo_root/:data)   
    end
    copy_data(:extra,  repo_root/:config)
    write_repo_config(root: repo_root)
    @blog = self.new
    @blog
  rescue => err
    puts "Can't create blog repo: '#{repo_root}' - #{err}"
    puts err.backtrace.join("\n")
  end

  def self.open(root_rel = ".blogs")
    log!(enter: __method__, args: [root_rel])
    self.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    blog = self.new(root_rel)
  rescue => err
    _tmp_error(err)
  end

  def initialize(root_rel = ".blogs")   # always assumes existing blog
    log!(enter: "initialize", args: [root_rel])
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?

    @root = Dir.pwd/root_rel
    write_repo_config(root: @root)
    get_repo_config
    @views = retrieve_views
    self.view = File.read(@root/"data/VIEW").chomp
    md = Dir.pwd.match(%r[.*/views/(.*?)/])
    if md
      @view_name = md[1]
      @view = str2view(@view_name)
    end
    @sequence = get_sequence
    @post_views = []
    @post_tags = []
  end

  def _generate_global
    vars = read_vars("#@root/data/universal.lt3")
    gfile = "#@root/data/global.lt3"
    global = File.read(gfile)
    global.gsub!(/AUTHOR/,  vars["author"])
    global.gsub!(/SITE/,    vars["site"])
    global.gsub!(/FONT/,    vars["font.family"])
    global.gsub!(/CHARSET/, vars["charset"])
    global.gsub!(/LOCALE/,  vars["locale"])
    File.write(gfile, global)
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
    preprocess cwd: dir, src: @root/:drafts/sourcefile, dst: @root/:posts/sourcefile.sub(/.lt3/, ",html"),  # ZZZ
               mix: "liveblog"  # , debug: true
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
      when "[no view]"
        # puts "Warning: No current view set"
        @view = nil
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
    File.read(@root/"data/sequence").to_i
  end

  def next_sequence
    log!(enter: __method__, level: 3)
    @sequence += 1
    dump(@sequence, @root/"data/sequence")
    @sequence
  end

  def viewdir(v = nil)   # delete?
    log!(enter: __method__, args: [v], level: 3)
    v ||= @view
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    return @root/:views/v
  end

  def self.exist?
    log!(enter: __method__, level: 3)
    Dir.exist?(DotDir)
  end

  def mark_last_published(str)
    log!(enter: __method__, args: [str], level: 2)
    dump(str, "#{self.view.dir}/last_published")
  end

  def add_view(view_name)
    log!(enter: __method__, args: [view_name], level: 2)
    view = RuneBlog::View.new(view_name)
    self.view = view    # current view
    File.write(@root/"data/VIEW", view_name)
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
    make_empty_view_tree(view_name)
    add_view(view_name)
    mark_last_published("Initial creation")
    system("cp #@root/data/global.lt3 #@root/views/#{view_name}/themes/standard/global.lt3")
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
    depend = [post_entry_name]
    html = "/tmp/post_entry.html"
    preprocess src: post_entry_name, dst: html,
               call: ".nopara"  # , deps: depend  # , debug: true
    @_post_entry ||= File.read(html)
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
    if posts.size > 0
      wanted = [8, posts.size].min  # estimate how many we want?
      enum = posts.each
      entries = []
      wanted.times do
        postid = File.basename(enum.next)
        postid = postid.to_i
        entry = index_entry(postid)
        entries << entry
        text << entry
      end
    else
      text << <<-HTML
        <svg width="95%" height="75%" viewBox="0 0 95% 95%">
          <style> .huge { font:  italic 90px sans-serif; fill: white } </style>
          <rect x="0" y="0" rx="50" ry="50" width="95%" height="95%" fill="lightblue"/>
          <text x="120" y="250" class=huge>No posts</text>
          <text x="120" y="350" class=huge>here yet</text>
        </svg>
      HTML
    end
    text << "</body></html>"
    File.write(@vdir/:remote/file, text)
    return posts.size
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
    File.write(@root/"data/VIEW", view)
    # write_repo_config
    self.view = view   # error checking?
  end

  def generate_index(view)
    log!(enter: __method__, args: [view], pwd: true, dir: true)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    @vdir = @root/:views/view
    num = collect_recent_posts("recent.html")
    return num
  rescue => err
    _tmp_error(err)
  end

  def generate_view(view)  # huh?
    log!(enter: __method__, args: [view])
    vdir = @root/:views/view
    @theme = @root/:views/view/:themes/:standard
    depend = [vdir/"remote/etc/blog.css.lt3", @theme/"global.lt3", 
             @theme/"blog/head.lt3", 
             # @theme/"navbar/navbar.lt3",
             @theme/"blog/index.lt3"]   # FIXME what about assets?
    preprocess cwd: vdir/"themes/standard/etc", # deps: depend, debug: true,
               src: "blog.css.lt3", copy: vdir/"remote/etc/", 
               call: ".nopara" # , dst: "blog.css"
    preprocess cwd: vdir/"themes/standard", deps: depend, force: true,
               src: "blog/generate.lt3", dst: vdir/:remote/"index.html", 
               call: ".nopara"
    copy!("#{vdir}/themes/standard/banner/*", "#{vdir}/remote/banner/")  # includes navbar/
    copy("#{vdir}/assets/*", "#{vdir}/remote/assets/")
# rebuild widgets
    copy_widget_html(view)
  rescue => err
    STDERR.puts err
    STDERR.puts err.backtrace.join("\n")
    # _tmp_error(err)
  end

  def _get_views(draft)
    log!(enter: __method__, args: [draft], level: 2)
    # FIXME dumb code
    view_line = File.readlines(draft).grep(/^.views /)
    raise "More than one .views call in #{draft}" if view_line.size > 1
    raise "No .views call in #{draft}" if view_line.size < 1
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
    preprocess cwd: pdraft, src: draft, dst: "guts.html",
               mix: "liveblog"  # , debug: true
    _post_metadata(draft, pdraft)
    # Step 2...
    vposts = @root/:views/view_name/:posts
    copy!(pdraft, vposts)    # ??
    # Step 3..
    copy(pdraft/"guts.html", @theme/:post) 
    copy(pdraft/"vars.lt3",  @theme/:post) 
    # Step 4...
    # FIXME dependencies?
    preprocess cwd: @theme/:post, src: "generate.lt3", force: true, 
               dst: remote/ahtml, copy: @theme/:post,
               call: ".nopara"    # , debug: true
    copy_widget_html(view_name)
  rescue => err
    _tmp_error(err)
  end

  def generate_post(draft, force = false)
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

end
