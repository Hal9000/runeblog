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
require 'exceptions'

###

module ErrorChecks
  def check_nonempty_string(str)
    confirm(ExpectedString, str.inspect, str.class) { str.is_a?(String) && ! str.empty? }
  end

  def check_view_parameter(view)
    confirm(ExpectedView, view, view.class) { view.is_a?(String) || view.is_a?(RuneBlog::View) }
  end

  def check_integer(num)
    confirm(ExpectedInteger, num, num.class) { num.is_a? Integer }
  end

  def confirm(exception, *args, &block)
    # raise if block is NOT true
    raise send(exception.to_s, *args) if ! block.call
  end

  def check_error(exception, *args, &block)
    # raise if block IS true
    raise send(exception.to_s, *args) if block.call
  end
end

class RuneBlog
 
  DotDir     = ".blogs"
  ConfigFile = "config"
  Themes     = RuneBlog::Path/"../themes"

  include Helpers
  include ErrorChecks

  class << self
    attr_accessor :blog
    include Helpers
    include ErrorChecks
  end

  attr_reader   :views, :sequence
  attr_accessor :root,  :editor, :features
  attr_accessor :view   # overridden
  attr_accessor :post

  attr_accessor :post_views, :post_tags, :dirty_views


    class Default

    # This will all become much more generic later.

    def RuneBlog.post_template(num: 0, title: "No title", date: nil, view: "test_view", 
                               teaser: "No teaser", body: "No body", tags: ["untagged"], 
                               views: [], back: "javascript:history.go(-1)", home: "no url")
      arglist = [num, title, date, view, teaser, body, tags, views, back, home]
      log!(enter: __method__, args: arglist, level: 3)
      viewlist = (views + [view.to_s]).uniq.join(" ")
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
  rescue => err
    abort "Error in #{__method__}: #{err}\n #{err.backtrace.join("\n")}"
  end

  def self.create_new_blog_repo(root_rel = ".blogs")
    log!(enter: __method__, args: [root_rel])
    check_error(BlogRepoAlreadyExists) { Dir.exist?(root_rel) }
    check_nonempty_string(root_rel)
    repo_root = Dir.pwd/root_rel

    create_dirs(repo_root)
    Dir.chdir(repo_root) do
      create_dirs(:data, :config, :widgets, :drafts, :views, :posts)  # ?? widgets?
      get_all_widgets("widgets")
      new_sequence
    end
    unless File.exist?(repo_root/"data/VIEW")
      copy_data(repo_root/:data)   
    end
    write_repo_config(root: repo_root)
    # Weird. Like a singleton - dumbass circular dependency?
    self.blog = blog = self.new
    blog
  rescue => err
    puts "Can't create blog repo: '#{repo_root}' - #{err}"
    puts err.backtrace.join("\n")
  end

  def self.open(root_rel = ".blogs")
    raise "Not impl"
    log!(enter: __method__, args: [root_rel])
    blog = self.new(root_rel)
  rescue => err
    _tmp_error(err)
  end

################

  def self.read(root_rel = ".blogs")   # always assumes existing blog
    log!(enter: "RuneBlog.read", args: [root_rel])
    RuneBlog.new(root_rel)
  rescue => err
    puts "ERROR - #{err.inspect}"
    # puts "Error - see stderr.out"
    puts err.inspect # + "\n" + err&.backtrace
    sleep 3
  end

  def initialize(root_rel = ".blogs")    ##### FIXME ??
    # @blog = instance    # Duhhh
    @root = Dir.pwd/root_rel
    # _init_get_view    ##########??????
    # self.class.blog = self   # Weird, like singleton. Dumbass circular dependency?
    RuneBlog.blog = self
    dirs = subdirs("#@root/views/").sort
    @views = dirs.map {|name| RuneBlog::View.new(name) }
    @curr = str2view(File.read(@root/"data/VIEW").chomp)
    @view = @curr
    # ...was init_get_view
    @sequence, @post_views, @post_tags = get_sequence, [], []
    get_repo_config
    read_features
  end

  def complete_file(name, vars, hash)
    debugging = vars.nil?
    return if hash.empty?
    text = File.read(name)
    if vars.nil?   # FIXME dumbest hack ever?
      vars = {}
      hash.values.each {|val| vars[val] = val }
    end

    hash.each_pair {|key, var| text.gsub!(key, vars[var]) }
    File.write(name, text)
  end

  def _generate_settings(view = nil)
    vars = read_vars("#@root/data/universal.lt3")
    hash = {/AUTHOR/  => "view.author",
            /SITE/    => "view.site",
            /FONT/    => "font.family",
            /CHARSET/ => :charset,
            /LOCALE/  => :locale}

    # rubytext.txt - LATER
    # complete_file(settings/"rubytext.txt", {}

    if view
      settings = @root/view/"settings"
      ### ??? Where to get hash of view-specific vars?

      # features.txt - handle specially
      fname = settings/"features.txt"

      # view.txt
      complete_file(settings/"view.txt", 
                        /AUTHOR/   => "view.author",
                        /TITLE/    => "view.title",
                        /SUBTITLE/ => "view.subtitle",
                        /SITE/     => "view.site")

      # publish.txt
      complete_file(settings/"publish.txt", 
                        /USER/    => "publish.user",
                        /SERVER/  => "publish.server",
                        /DOCROOT/ => "publish.docroot",
                        /PATH/    => "publish.path",
                        /PROTO/   => "publish.proto")
                
      # recent.txt - SKIP THIS?
      complete_file(settings/"recent.txt",  {})
    end
  end

  def _generate_global
    vars = read_vars("#@root/data/universal.lt3")
    gfile = "#@root/data/global.lt3"
    hash = {/AUTHOR/  => "univ.author",
            /SITE/    => "univ.site",
            /FONT/    => "font.family",
            /CHARSET/ => :charset,
            /LOCALE/  => :locale}
    complete_file(gfile, vars, hash)
    _generate_settings
  end

  # FIXME reconcile with _get_draft data

  def read_metadata
    meta = read_pairs!("metadata.txt")
    meta.views = meta.views.split
    meta.tags  = meta.tags.split
    RuneBlog.blog.post = meta
    meta
  end

  def _deploy_local(dir)
    log!(enter: __method__, args: [dir], level: 1)
    Dir.chdir(dir) do
      meta = read_metadata
      meta.views.each do |v| 
        next unless _check_view?(v)
        system!("cp *html #@root/views/#{v}/remote", show: true)
      end
    end
  rescue => err
    _tmp_error(err)
  end

  def process_post(sourcefile)
    log!(enter: __method__, args: [sourcefile], level: 2)
    nslug = sourcefile.sub(/.lt3/, "")
    dir = @root/:posts/nslug
    create_dirs(dir)
    # FIXME dependencies?
    preprocess cwd: dir, src: @root/:drafts/sourcefile, dst: @root/:posts/sourcefile.sub(/.lt3/, ".html"),  # ZZZ
               mix: "liveblog", vars: @view.globals  # , debug: true
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
    check_nonempty_string(name)
    views.any? {|x| x.name == name }
  end

  def str2view(str)
    log!(enter: __method__, args: [str], level: 3)
    check_nonempty_string(str)  # redundant?
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
    if arg == "[no view]"
      @view = nil
      return
    end
    case arg
      when RuneBlog::View
        @view = arg
        @view.get_globals(true)
      when String
        new_view = str2view(arg)
        check_error(NoSuchView, arg) { new_view.nil? }
        @view = new_view
      else 
        raise CantAssignView(arg.class.to_s)
    end
    read_features(@view)
    @view.get_globals(true)
    _set_publisher
    File.write(@root/"data/VIEW", @view.to_s)
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
    return @view if v.nil?
    check_nonempty_string(v)
    dir = @root/:views/v
    puts "Dir = #{dir}"  # ; sleep 5
    return dir
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
puts "#{__method__}: cmd = #{cmd.inspect}"
      system!(cmd)
      cmd = "cp -r widgets views/#{view_name}"
      system!(cmd)
    end
  rescue => err
    _tmp_error(err)
  end

  def check_valid_new_view(view_name)
    log!(enter: __method__, args: [view_name], level: 3)
    check_nonempty_string(view_name)
    vdir = @root/:views/view_name
    check_error(ViewAlreadyExists, view_name) { self.views.map(&:to_s).include?(view_name) }
    check_error(DirAlreadyExists, view_name) { Dir.exist?(vdir) }
    return true
  end

  def create_view(view_name)
    log!(enter: __method__, args: [view_name], level: 2)
    make_empty_view_tree(view_name)
    add_view(view_name)
    src, dst = "#@root/data/global.lt3", "#@root/views/#{view_name}/global.lt3"
    system("cp #{src} #{dst}")
    mark_last_published("Initial creation")
    @view.get_globals(true)
  rescue => err
    _tmp_error(err)
  end

  def delete_view(name, force = false)
    log!(enter: __method__, args: [name, force])
    check_nonempty_string(name)
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

    posts = posts.select {|x| File.basename(x).to_i == postid }
    postdir = exactly_one(posts, posts.join("/"))
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
               call: ".nopara", vars: @view.globals    # , deps: depend  # , debug: true
    @_post_entry = File.read(html)
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

  def collect_recent_posts(file = "recent.html")
    log!(enter: __method__, args: [file], level: 3)
    vars = self.view.globals
    text = <<-HTML
      <html>
      <head><link rel="stylesheet" href="etc/blog.css"></head>
      <body style="background-color: #{vars["recent.bgcolor"]}">
    HTML
    posts = _sorted_posts
    if posts.size > 0
      # estimate how many we want
      wanted = [vars["recent.count"].to_i, posts.size].min
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
    posts.sort
  end

  def drafts
    log!(enter: __method__, level: 3)
    curr_drafts = self.all_drafts
    list = []
    curr_drafts.each do |draft|
      postdir = @root/:views/self.view/:posts/draft.sub(/.lt3$/, "")
      next unless Dir.exist?(postdir)
      meta = nil
      Dir.chdir(postdir) { meta = read_metadata }
      list << draft if meta.views.include?(self.view.to_s)
    end
    # curr_drafts
    list.sort
  end

  def all_drafts
    log!(enter: __method__, level: 3)
    dir = @root/:drafts
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
    drafts.sort
  end

  def change_view(view)
    log!(enter: __method__, args: [view], level: 3)
    check_view_parameter(view)
    File.write(@root/"data/VIEW", view)
    # write_repo_config
    self.view = view   # error checking?
  end

  def generate_index(view)
    log!(enter: __method__, args: [view], pwd: true, dir: true)
    check_view_parameter(view)
    @vdir = @root/:views/view
    num = collect_recent_posts
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
    preprocess cwd: vdir/"themes/standard/etc", src: "blog.css.lt3", 
               copy: vdir/"remote/etc/", call: [".nopara"], strip: true , vars: @view.globals 
    preprocess cwd: vdir/"themes/standard", deps: depend, force: true,
               src: "blog/generate.lt3", dst: vdir/:remote/"index.html", 
               call: ".nopara" , vars: @view.globals 
    copy!("#{vdir}/themes/standard/banner/*", "#{vdir}/remote/banner/")  # includes navbar/
    copy("#{vdir}/assets/*", "#{vdir}/remote/assets/")
    # rebuild widgets?
    copy_widget_html(view)
  rescue => err
    STDERR.puts err
    STDERR.puts err.backtrace.join("\n")
    # _tmp_error(err)
  end

  def _get_views(draft)
    log!(enter: __method__, args: [draft], level: 2)
    # FIXME dumb code
    view_line = exactly_one(File.readlines(draft).grep(/^.views /), ".view line")
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
    hash = {}
    Dir.chdir(pdraft) do 
      excerpt = File.read("teaser.txt")
      meta = read_metadata
      date = meta.date
      longdate = ::Date.parse(date).strftime("%B %e, %Y")
      title = meta.title
      tags = meta.tags
      # FIXME simplify
      addvar(hash, "post.num" => pnum, 
                   "post.aslug" => aslug,
                   "post.date" => date,      
                   title: title.chomp, 
                   teaser: excerpt.chomp,    
                   longdate: longdate,
                   "post.nslug" => pnum + "-" + aslug,
                   "post.tags" => tags.join(" "))
    end
    hash
  rescue => err
    _tmp_error(err)
  end

  def copy_widget_html(view)
    log!(enter: __method__, level: 2)
# log! str:  "=== cwh cp 1"
    vdir = @root/:views/view
    remote = vdir/:remote
    wdir = vdir/:widgets
    widgets = Dir[wdir/"*"].select {|w| File.directory?(w) }
# log! str:  "=== cwh cp 2"
    widgets.each do |w|
      dir = File.basename(w)
      rem = w.sub(/widgets/, "remote/widgets")
# log! str:  "=== cwh cp 3  w = #{w.inspect}"
      create_dirs(rem)
      files = Dir[w/"*"]
      # files = files.select {|x| x =~ /(html|css)$/ }
      tag = File.basename(w)
# log! str:  "=== cwh cp 4   tag = #{tag.inspect}"
      files.each {|file| system!("cp #{file} #{rem}") }  # , show: true) }
# log! str:  "=== cwh cp 5   tag was #{tag.inspect}"
    end
# log! str:  "=== cwh cp 6"
  rescue => err
    _tmp_error(err)
  end

  def _handle_post(draft, view_name = self.view.to_s)
    log!(enter: __method__, args: [draft, view_name], level: 2)
    return unless _check_view?(view_name)

    fname = File.basename(draft)       # 0001-this-is-a-post.lt3
    nslug = fname.sub(/.lt3$/, "")     # 0001-this-is-a-post
    aslug = nslug.sub(/\d\d\d\d-/, "") # this-is-a-post
    ahtml = aslug + ".html"            # this-is-a-post.html
    pdraft = @root/:posts/nslug
    remote = @root/:views/view_name/:remote
    @theme = @root/:views/view_name/:themes/:standard
    pmeta  = @root/:views/view_name/:posts/nslug


    create_dirs(pdraft)                                # Step 1...
    @view.globals ||= {}
args = {cwd: pdraft, src: draft, dst: "guts.html", 
        mix: "liveblog", vars: @view.globals}
    preprocess cwd: pdraft, src: draft,                # FIXME dependencies?
               dst: "guts.html", mix: "liveblog", vars: @view.globals
    hash = _post_metadata(draft, pdraft)
    hash[:CurrentPost] = pmeta
    vposts = @root/:views/view_name/:posts             # Step 2...
    copy!(pdraft, vposts)    # ??
    copy(pdraft/"guts.html", vposts/nslug)             # Step 3...
                                                       # Step 4...
    preprocess cwd: pmeta, src: "../../themes/standard/post/generate.lt3", 
               force: true, vars: hash, 
               dst: remote/ahtml, call: ".nopara"
    FileUtils.rm_f(remote/"published")
    timelog("Generated", remote/"history")
    copy_widget_html(view_name)
  rescue => err
    puts "Error - see stdout.txt"
    STDERR.puts err.inspect
    STDERR.puts err&.backtrace
    # _tmp_error(err)
    # puts err.backtrace.join("\n")
  end

  def _check_view?(view)
    flag = self.view?(view)
    puts "        Warning: '#{view}' is not a view" unless flag
    flag
  end

  def generate_post(draft, force = false)
    log!(enter: __method__, args: [draft], level: 1)
    views = _get_views(draft)
    views.each do |view| 
      _handle_post(draft, view)
    end
    # For current view: 
    slug = File.basename(draft).sub(/.lt3$/, "")
    postdir = self.view.dir/"remote/post/"/slug
  rescue => err
    _tmp_error(err)
  end

  def remove_post(num)
    log!(enter: __method__, args: [num], level: 1)
    check_integer(num)   # FIXME update original draft .views
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
    check_integer(num)
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
    check_integer(num)
    tag = prefix(num)
    system!("rm -rf #@root/drafts/#{tag}-*")
  end

  def make_slug(meta)
    log!(enter: __method__, args: [meta], level: 3)
    check_nonempty_string(meta.title)
    label = '%04d' % meta.num   # FIXME can do better
    slug0 = meta.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    str = "#{label}-#{slug0}"
    meta.slug = str
    str
  end
end

end
