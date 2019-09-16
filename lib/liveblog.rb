require 'ostruct'
require 'pp'
require 'date'

require 'livetext'
require 'runeblog'

errfile = File.new("liveblog.out", "w")
STDERR.reopen(errfile)

def init_liveblog    # FIXME - a lot of this logic sucks
  here = Dir.pwd
  dir = here
  loop { dir = Dir.pwd; break if File.exist?("config"); Dir.chdir("..") }
  Dir.chdir(here)
  @blog = $_blog = RuneBlog.new(dir)
  @root = @blog.root
  @view = @blog.view
  @view_name = @blog.view.name
  @vdir = @blog.view.dir
  @version = RuneBlog::VERSION
  @theme = @vdir + "/themes/standard/"
end

def post
  @meta = OpenStruct.new
  @meta.num = _args[0]
  _out "  <!-- Post number #{@meta.num} -->\n "
end

def _view_from_cwd
  md = Dir.pwd.match(%r[.*/views/(.*?)/])
  return md[1] if md
  nil
end

def quote
  _passthru "<blockquote>"
  _passthru _body
  _passthru "</blockquote>"
  _optional_blank_line
end

def categories   # does nothing right now
end

def style
  fname = _args[0]
  _passthru %[<link rel="stylesheet" href="???/etc/#{fname}')">]
end

# Move elsewhere later!

def h1; _passthru "<h1>#{@_data}</h1>"; end
def h2; _passthru "<h2>#{@_data}</h2>"; end
def h3; _passthru "<h3>#{@_data}</h3>"; end
def h4; _passthru "<h4>#{@_data}</h4>"; end
def h5; _passthru "<h5>#{@_data}</h5>"; end
def h6; _passthru "<h6>#{@_data}</h6>"; end

def hr; _passthru "<hr>"; end

def emit   # send to STDOUT?
  @emit = true
  case _args.first
    when "off";  @emit = false
    when "on";   @emit = true
  end
end

### inset

def inset
  lines = _body
  box = ""
  lines.each do |line| 
    line = line.dup
    if line[0] == "/"  # Only into inset
      line[0] = ' '
      box << line.dup + " "
      line.replace(" ")
    end
    if line[0] == "|"  # Into inset and body
      line[0] = ' '
      box << line.dup + " "
    end
    _passthru(line)
  end
  lr = _args.first
  wide = _args[1] || "25"
  _passthru "<div style='float:#{lr}; width: #{wide}%; padding:8px; padding-right:12px; font-family:verdana'>"
  _passthru '<b><i>'
  _passthru box
  _passthru_noline '</i></b></div>'
  _optional_blank_line
end

def _errout(*args)
  ::STDERR.puts *args
end

def _passthru(line)
  return if line.nil?
  line = _format(line)
  _out line + "\n"
  _out "<p>" if line.empty? && ! @_nopara
end

def _passthru_noline(line)
  return if line.nil?
  line = _format(line)
  _out line
  _out "<p>" if line.empty? && ! @_nopara
end

def title
  raise "'post' was not called" unless @meta
  title = @_data.chomp
  @meta.title = title
  setvar :title, title
  _out %[<h1 class="post-title">#{title}</h1><br>]
  _optional_blank_line
end

def pubdate
  raise "'post' was not called" unless @meta
  _debug "data = #@_data"
  # Check for discrepancy?
  match = /(\d{4}).(\d{2}).(\d{2})/.match @_data
  junk, y, m, d = match.to_a
  y, m, d = y.to_i, m.to_i, d.to_i
  @meta.date = ::Date.new(y, m, d)
  @meta.pubdate = "%04d-%02d-%02d" % [y, m, d]
  _optional_blank_line
end

def image   # primitive so far
  _debug "img: huh? <img src=#{_args.first}></img>"
  fname = _args.first
  path = "assets/#{fname}"
  _out "<img src=#{path}></img>"
  _optional_blank_line
end

def tags
  raise "'post' was not called" unless @meta
  _debug "args = #{_args}"
  @meta.tags = _args.dup || []
  _optional_blank_line
end

def views
  raise "'post' was not called" unless @meta
  _debug "data = #{_args}"
  @meta.views = _args.dup
  _optional_blank_line
end

def pin
  raise "'post' was not called" unless @meta
  _debug "data = #{_args}"
  # verify only already-specified views?
  @meta.pinned = _args.dup
  _optional_blank_line
end

def list
  _out "<ul>"
  _body {|line| _out "<li>#{line}</li>" }
  _out "</ul>"
  _optional_blank_line
end

def list!
  _out "<ul>"
  lines = _body.each 
  loop do 
    line = lines.next
    line = _format(line)
    if line[0] == " "
      _out line
    else
      _out "<li>#{line}</li>"
    end
  end
  _out "</ul>"
  _optional_blank_line
end

def write_post
  raise "'post' was not called" unless @meta
  save = Dir.pwd
  @postdir.gsub!(/\/\//, "/")  # FIXME unneeded?
  Dir.mkdir(@postdir) unless Dir.exist?(@postdir) # FIXME remember assets!
  Dir.chdir(@postdir)
  @meta.views = @meta.views.join(" ") if @meta.views.is_a? Array
  @meta.tags  = @meta.tags.join(" ") if @meta.tags.is_a? Array
  File.write("teaser.txt", @meta.teaser)
  
  fields = [:num, :title, :date, :pubdate, :views, :tags]
  
  fname2 = "metadata.txt"
  f2 = File.open(fname2, "w") do |f2| 
    fields.each {|fld| f2.puts "#{fld}: #{@meta.send(fld)}" }
  end
  Dir.chdir(save)
rescue => err
  puts "err = #{err}"
  puts err.backtrace.join("\n")
end

def teaser
  raise "'post' was not called" unless @meta
  @meta.teaser = _body_text
  setvar :teaser, @meta.teaser
  _out @meta.teaser + "\n"
  # FIXME
end

def finalize
  unless @meta
    puts @live.body
    return
  end
  if @blog.nil?
    return @meta
  end

  @slug = @blog.make_slug(@meta)
  slug_dir = @slug
  @postdir = @blog.view.dir + "/posts/#{slug_dir}"
  STDERR.puts "--- finalize: pwd = #{Dir.pwd} postdir = #@postdir"
  write_post
  @meta
end
 
$Dot = self   # Clunky! for dot commands called from Functions class

# Find a better way to do this?

class Livetext::Functions

  def br(n="1")
    # Thought: Maybe make a way for functions to "simply" call the
    #   dot command of the same name?? Is this trivial??
    n = n.empty? ? 1 : n.to_i
    "<br>"*n
  end

  def h1(param); "<h1>#{param}</h1>"; end
  def h2(param); "<h2>#{param}</h2>"; end
  def h3(param); "<h3>#{param}</h3>"; end
  def h4(param); "<h4>#{param}</h4>"; end
  def h5(param); "<h5>#{param}</h5>"; end
  def h6(param); "<h6>#{param}</h6>"; end

  def hr(param=nil)
    $Dot.hr
  end

  def image(param)
    "<img src='#{param}'></img>"
  end

end

###### experimental...

class Livetext::Functions
  def _var(name)
    ::Livetext::Vars[name] || "[:#{name} is undefined]"
  end

  def link
    file, cdata = self.class.param.split("||", 2)
    %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}#{file}" title="#{_var(:title)}">]
  end
end

def _var(name)  # FIXME scope issue!
  ::Livetext::Vars[name] || "[:#{name} is undefined]"
end

def head  # Does NOT output <head> tags
  args = _args
  args.each do |inc|
    self.data = inc
    _include
  end
  # Depends on vars: title, desc, host
  defaults = {}
  defaults = { "charset"        => %[<meta charset="utf-8">],
               "http-equiv"     => %[<meta http-equiv="X-UA-Compatible" content="IE=edge">],
               "title"          => %[<title>\n  #{_var(:blog)} | #{_var(:blog_desc)}\n  </title>],
               "generator"      => %[<meta name="generator" content="Runeblog v #@version">],
               "og:title"       => %[<meta property="og:title" content="#{_var(:blog)}">],
               "og:locale"      => %[<meta property="og:locale" content="#{_var(:locale)}">],
               "description"    => %[<meta name="description" content="#{_var(:blog_desc)}">],
               "og:description" => %[<meta property="og:description" content="#{_var(:blog_desc)}">],
               "linkc"          => %[<link rel="canonical" href="#{_var(:host)}">],
               "og:url"         => %[<meta property="og:url" content="#{_var(:host)}">],
               "og:site_name"   => %[<meta property="og:site_name" content="#{_var(:blog)}">],
               "style"          => %[<link rel="stylesheet" href="etc/blog.css">],
               "feed"           => %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}/feed.xml" title="#{_var(:blog)}">],
               "favicon"        => %[<link rel="shortcut icon" type="image/x-icon" href="../etc/favicon.ico">\n <link rel="apple-touch-icon" href="../etc/favicon.ico">]
             }
  result = {}
  lines = _body
  lines.each do |line|
    line.chomp
    word, remain = line.split(" ", 2)
    case word
      when "viewport"
        result["viewport"] = %[<meta name="viewport" content="#{remain}">]
      when "script"  # FIXME this is broken
        file = remain
        text = File.read(file)
        result["script"] = Livetext.new.transform(text)
      when "style"
        result["style"] = %[<link rel="stylesheet" href="('/etc/#{remain}')">]
      # Later: allow other overrides
      when ""; break
    else
STDERR.puts "-- got '#{word}'; old value = #{result[word].inspect}"
      if defaults[word]
        result[word] = %[<meta property="#{word}" content="#{remain}">]
STDERR.puts "-- new value = #{result[word].inspect}"
      else
        puts "Unknown tag '#{word}'"
      end
    end
  end
  hash = defaults.dup.update(result)  # FIXME collisions?

# _out "<!-- "; _out hash.inspect; _out "--> "
  hash.each_value {|x| _out "  " + x }
  _out "<body>"
end

########## newer stuff...

def meta
  args = _args
  enum = args.each
  str = "<meta"
  arg = enum.next
  loop do 
    if arg.end_with?(":")
      str << " " << arg[0..-2] << "="
      a2 = enum.next
      str << %["#{a2}"]
    else
      STDERR.puts "=== meta error?"
    end
    arg = enum.next
  end
  str << ">"
  _out str
end

def recent_posts    # side-effect
  _out %[<div class="col-lg-9 col-md-9 col-sm-9 col-xs-12">]
  all_teasers
  _out %[</div>]
end

def sidebar
  _out %[<div class="col-lg-3 col-md-3 col-sm-3 col-xs-12">]
  _body do |line|
    tag = line.chomp.strip
    self.data = "sidebar/#{tag.downcase}.lt3"
    _include 
  end
  _out %[</div>]
end

def sidebar!
  _out %[<div class="col-lg-3 col-md-3 col-sm-3 col-xs-12">]
  _args do |line|
    tag = line.chomp.strip
    self.data = "sidebar/#{tag.downcase}.lt3"
    _include 
  end
  _out %[</div>]
end

def stylesheet
  lines = _body
  url = lines[0]
  integ = lines[1]
  cross = lines[2] || "anonymous"
  _out %[<link rel="stylesheet" href="#{url}" integrity="#{integ}" crossorigin="#{cross}"></link>]
end

def script
  lines = _body
  url = lines[0]
  integ = lines[1]
  cross = lines[2] || "anonymous"
  _out %[<script src="#{url}" integrity="#{integ}" crossorigin="#{cross}"></script>]
end


### How this next bit works:
### 
###   all_teasers will call _find_recent_posts
### 
###   _find_recent_posts will search higher in the directory structure
###   for where the posts are (0001, 0002, ...) NOTE: This implies you
###   must be in some specific place when this code is run.
###   It returns the 20 most recent posts.
### 
###   all_teasers will then pick a small number of posts and call _teaser

###   on each one. (The code in _teaser really belongs in a small template
###   somewhere.)
### 

def _find_recent_posts
  @vdir = _var(:FileDir).match(%r[(^.*/views/.*?)/])[1]
  posts = nil
  dir_posts = @vdir + "/posts"
  entries = Dir.entries(dir_posts)
  posts = entries.grep(/^\d\d\d\d/).map {|x| dir_posts + "/" + x }
  posts.select! {|x| File.directory?(x) }
  # directories that start with four digits
  posts = posts.sort {|a, b| b.to_i <=> a.to_i }  # sort descending
  posts[0..19]  # return 20 at most
end

def all_teasers
  open = <<-HTML
      <section class="posts">
  HTML
  close = <<-HTML
      </section>
  HTML

  text = <<-HTML
    <html>
    <head><link rel="stylesheet" href="etc/blog.css"></head>
    <body>
  HTML
  posts = _find_recent_posts
  wanted = [5, posts.size].min  # estimate how many we want?
  enum = posts.each
  wanted.times do
    postid = File.basename(enum.next)
    postid = postid.to_i
    text << _teaser(postid)    # side effect! calls _out
  end
  text << "</body></html>"
  File.write("recent.html", text)
  _out %[<iframe style="width: 100vw;height: 100vh;position: relative;" src='recent.html' width=100% frameborder="0" allowfullscreen></iframe>]
end

def _post_lookup(postid)    # side-effect
  # .. = templates, ../.. = views/thisview
  slug = title = date = teaser_text = nil

  dir_posts = @vdir + "/posts"
  posts = Dir.entries(dir_posts).grep(/^\d\d\d\d/).map {|x| dir_posts + "/" + x }
  posts.select! {|x| File.directory?(x) }

  post = posts.select {|x| File.basename(x).to_i == postid }
  raise "Error: More than one post #{postid}" if post.size > 1
  postdir = post.first
  vp = RuneBlog::ViewPost.new(@blog.view, postdir)
  vp
end

def _interpolate(str, context)   # FIXME move this later
  wrapped = "%[" + str.dup + "]"  # could fail...
  eval(wrapped, context)
end

def _teaser(slug)
  id = slug.to_i
  text = nil
  post_entry_name = @theme + "blog/post_entry.lt3"
  @_post_entry ||= File.read(post_entry_name)
  vp = _post_lookup(id)
  nslug, aslug, title, date, teaser_text = 
    vp.nslug, vp.aslug, vp.title, vp.date, vp.teaser_text
  path = vp.path
  url = "#{path}/#{aslug}.html"    # Should be relative to .blogs!! FIXME
    date = Date.parse(date)
    date = date.strftime("%B %e<br>%Y")
    text = _interpolate(@_post_entry, binding)
  text
end

def _card_generic(card_title:, middle:, extra: "")
  front = <<-HTML
    <div class="card #{extra} mb-3">
      <div class="card-body">
        <h5 class="card-title">#{card_title}</h5>
  HTML

  tail = <<-HTML
      </div>
    </div>
  HTML
  text = front + middle + tail
  _out text + "\n "
end

def card_iframe
  title, lines = _data, _body
  lines.map!(&:chomp)
  url = lines[0].chomp
  stuff = lines[1..-1].join(" ")  # FIXME later
  middle = <<-HTML
    <iframe src="#{url}" #{stuff} 
            style="border: 0" height="350" 
            frameborder="0" scrolling="no">
    </iframe>
  HTML

  _card_generic(card_title: title, middle: middle, extra: "bg-dark text-white")
end

def card1
  title, lines = _data, _body
  lines.map!(&:chomp)

  card_text = lines[0]
  url, target, classname, cdata = lines[1].split(",", 4)

  middle = <<-HTML
    <p class="card-text">#{card_text}</p>
    <a href="#{url}" target="#{target}" class="#{classname}">#{cdata}</a>
  HTML

  _card_generic(card_title: title, middle: middle, extra: "bg-dark text-white")
end

def card2
  card_title = _data

# FIXME is this wrong??

  open = <<-HTML
    <div class="card mb-3">
      <div class="card-body">
        <h5 class="card-title">#{card_title}</h5>
      </div>
      <ul class="list-group list-group-flush">
  HTML
  _out open
  _body do |line|
    url, target, cdata = line.chomp.split(",", 3)
    _out %[<li class="list-group-item"><a href="#{url}" target="#{target}">#{cdata}</a> </li>]
  end
  close = %[       </ul>\n    </div>]
  _out close
rescue
  puts @live.body
end

def tag_cloud
  title = _data
  title = "Tag Cloud" if title.empty?
  open = <<-HTML
        <div class="card mb-3">
          <div class="card-body">
            <h5 class="card-title">#{title}</h5>
  HTML
  _out open
  _body do |line|
    line.chomp!
    url, target, classname, cdata = line.split(",", 4)
    _out %[<a href="#{url}" target="#{target}" class="#{classname}">#{cdata}</a>]
  end
rescue
  puts @live.body
end

def navbar
  title = _var(:blog)
  open = <<-HTML
    <nav class="navbar navbar-expand-lg navbar-light bg-light">
      <a class="navbar-brand" href="index.html">#{title}</a>
      <button class="navbar-toggler" 
              type="button" 
              data-toggle="collapse" 
              data-target="#navbarSupportedContent"
              aria-controls="navbarSupportedContent" 
              aria-expanded="false" 
              aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>

      <div class="collapse navbar-collapse pull-right" 
           id="navbarSupportedContent">
        <ul class="navbar-nav mr-auto">
  HTML
  close = <<-HTML
        </ul>
      </div>
    </nav>
  HTML

  first = true
  _out open
  _body do |line|
    href, cdata = line.chomp.strip.split(" ", 2)
    if first
      first = false
      _out %[<li class="nav-item active"> <a class="nav-link" href="#{href}">#{cdata}<span class="sr-only">(current)</span></a> </li>]
    else
      _out %[<li class="nav-item"> <a class="nav-link" href="#{href}">#{cdata}</a> </li>]
    end
  end
  _out close
end

