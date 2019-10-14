require 'ostruct'
require 'pp'
require 'date'

require 'runeblog'
require 'pathmagic'
require 'xlate'

# errfile = File.new("/tmp/liveblog.out", "w")
# STDERR.reopen(errfile)

def init_liveblog    # FIXME - a lot of this logic sucks
  here = Dir.pwd
  dir = here
  loop { dir = Dir.pwd; break if File.exist?("config"); Dir.chdir("..") }
  Dir.chdir(here)     #  here??? or dir??
  @blog = RuneBlog.new(dir)
  @root = @blog.root
  @view = @blog.view
  @view_name = @blog.view.name
  @vdir = @blog.view.dir
  @version = RuneBlog::VERSION
  @theme = @vdir/:themes/:standard
end

##################
# "dot" commands
##################

def post
  @meta = OpenStruct.new
  @meta.num = _args[0]
  _out "  <!-- Post number #{@meta.num} -->\n "
end

def backlink
  _out %[<br><a href="javascript:history.go(-1)">[Back]</a>]
end

def dropcap
  # Bad form: adds another HEAD
  _out <<-HTML
<head>
<style>
p:first-child:first-letter {
  color: #0000ff;
  float: left;
  font-family: Georgia;
  font-size: 75px;
  line-height: 60px;
  padding-top: 4px;
  padding-right: 8px;
  padding-left: 3px;
}
</style>
</head>
HTML
  _out " "
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


def make_main_links
  log!(enter: __method__)
  # FIXME remember strings may not be safe
  line = _data.chomp
  tag, card_title = *line.split(" ", 2)
  cardfile, mainfile = "#{tag}-card", "#{tag}-main"
  input = "list.data"
  log!(str: "Reading #{input}", pwd: true)
  pairs = File.readlines(input).map {|line| line.chomp.split(/, */, 2) }
  _write_main(mainfile, pairs, card_title, tag)
  _write_card(cardfile, mainfile, pairs, card_title, tag)
  log!(str: "...returning from method", pwd: true)
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
  path = :assets/fname
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

def write_post
  raise "'post' was not called" unless @meta
  @meta.views = @meta.views.join(" ") if @meta.views.is_a? Array
  @meta.tags  = @meta.tags.join(" ") if @meta.tags.is_a? Array
  _write_metadata
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
  # FIXME simplify this!
  unless @meta
    puts @live.body
    return
  end
  if @blog.nil?
    return @meta
  end

  @slug = @blog.make_slug(@meta)
  slug_dir = @slug
  @postdir = @blog.view.dir/:posts/slug_dir
  write_post
  @meta
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
               "title"          => %[<title>\n  #{_var(:blog)} | #{_var("blog.desc")}\n  </title>],
               "generator"      => %[<meta name="generator" content="Runeblog v #@version">],
               "og:title"       => %[<meta property="og:title" content="#{_var(:blog)}">],
               "og:locale"      => %[<meta property="og:locale" content="#{_var(:locale)}">],
               "description"    => %[<meta name="description" content="#{_var("blog.desc")}">],
               "og:description" => %[<meta property="og:description" content="#{_var("blog.desc")}">],
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
      if defaults[word]
        result[word] = %[<meta property="#{word}" content="#{remain}">]
      else
        puts "Unknown tag '#{word}'"
      end
    end
  end
  hash = defaults.dup.update(result)  # FIXME collisions?

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
  _out <<-HTML
    <div class="col-lg-9 col-md-9 col-sm-9 col-xs-12">
      <iframe id="main" style="width: 70vw; height: 100vh; position: relative;" 
       src='recent.html' width=100% frameborder="0" allowfullscreen>
      </iframe>
    </div>
  HTML
end

def _load_local(widget)
  Dir.chdir("widgets/#{widget}") do
# STDERR.puts "loadCP1 widget = #{widget.inspect}  pwd = #{Dir.pwd}"
    found = (require("./#{widget}") if File.exist?("#{widget}.rb"))
# STDERR.puts "loadCP2 found = #{found}"
    code = found ? ::RuneBlog::Widget.class_eval(widget.capitalize) : nil
# STDERR.puts "loadCP3 code = #{code.inspect}"
    code
  end
rescue => err
  STDOUT.puts err
  STDOUT.puts err.backtrace.join("\n")
  exit
end

def sidebar
  if _args.include? "off"
    _body { }  # iterate, do nothing
    return 
  end

  _out %[<div class="col-lg-3 col-md-3 col-sm-3 col-xs-12">]
  _body do |token|
    tag = token.chomp.strip.downcase
    wtag = :widgets/tag
    raise "Can't find #{wtag}" unless Dir.exist?(wtag)
    tcard = "#{tag}-card.html"

    code = _load_local(tag)
    code && Dir.chdir(wtag) { code.build }

#    if File.exist?(wtag/"SUBFILES")
#      children = Dir[wtag/"*.lt3"] - [wtag/tag+".lt3"]
#      children.each do |child|
#        dest = child.sub(/.lt3$/, ".html")
#        xlate src: child, dst: dest  # , debug: true
#      end
#    end
    xlate cwd: wtag, src: tag, dst: tcard  # , debug: true
    _include_file wtag/tcard
  end
  _out %[</div>]
rescue => err
  puts "err = #{err}"
  puts err.backtrace.join("\n")
  exit
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

def card_iframe
  title, lines = _data, _body
  lines.map!(&:chomp)
  url = lines[0].chomp
  stuff = lines[1..-1].join(" ")  # FIXME later
  middle = <<-HTML
    <iframe src="#{url}" #{stuff} 
            style="border: 0" #{stuff}
            frameborder="0" scrolling="no">
    </iframe>
  HTML

  _card_generic(card_title: title, middle: middle, extra: "bg-dark text-white")
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

###

def card1
  title, lines = _data, _body
  lines.map!(&:chomp)

  card_text = lines[0]
  url, classname, cdata = lines[1].split(",", 4)
  main = _main(url)

  middle = <<-HTML
    <p class="card-text">#{card_text}</p>
    <a #{main} class="#{classname}">#{cdata}</a>
  HTML

  _card_generic(card_title: title, middle: middle, extra: "bg-dark text-white")
end

def card2
  str = _data
  file, card_title = str.chomp.split(" ", 2) 
  card_title = %[<a #{_main(file)} style="text-decoration: none; color: black">#{card_title}</a>]

# FIXME is this wrong??

  open = <<-HTML
    <div class="card mb-3">
      <div class="card-body">
        <h5 class="card-title">#{card_title}</h5>
      <ul class="list-group list-group-flush">
  HTML
  _out open
  _body do |line|
    url, cdata = line.chomp.split(",", 3)
    main = _main(url)
    _out %[<li class="list-group-item"><a #{main}}">#{cdata}</a> </li>]
  end
  close = %[       </ul>\n    </div>\n  </div>]
  _out close
end

def tag_cloud
  title = _data
  title = "Tag Cloud" if title.empty?
  open = <<-HTML
        <div class="card mb-3">
          <div class="card-body">
            <h5 class="card-title">
              <button type="button" class="btn btn-primary" data-toggle="collapse" data-target="#tag-cloud">+</button>
              #{title}
            </h5>
            <div class="collapse" id="tag-cloud">
  HTML
  _out open
  _body do |line|
    line.chomp!
    url, classname, cdata = line.split(",", 3)
    main = _main(url)
    _out %[<a #{main} class="#{classname}">#{cdata}</a>]
  end
  close = %[       </div>\n    </div>\n  </div>]
  _out close
end

def navbar
  vdir = @blog.view.dir
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
  lines = _body
  lines.each do |line|
    basename, cdata = line.chomp.strip.split(" ", 2)
    full = :navbar/basename+".html"
    href_main = _main(full)
    if first
      first = false # hardcode this part??
      _out %[<li class="nav-item active"> <a class="nav-link" href="index.html">#{cdata}<span class="sr-only">(current)</span></a> </li>]
    else
      xlate cwd: "navbar", src: basename, dst: vdir/"remote/navbar"/basename+".html" # , debug: true
      _out %[<li class="nav-item"> <a class="nav-link" #{href_main}>#{cdata}</a> </li>]
    end
  end
  _out close
end

##################
# helper methods
##################

def _html_body(file, css = nil)
  file.puts "<html>"
  if css
    file.puts "    <head>"  
    file.puts "        <style>\n#{css}\n          </style>"
    file.puts "    </head>"  
  end
  file.puts "  <body>"
  yield
  file.puts "  </body>\n</html>"
end

def _write_card(cardfile, mainfile, pairs, card_title, tag)
  log!(str: "Creating #{cardfile}.html", pwd: true)
  url = mainfile
  url = :widgets/tag/mainfile + ".html"
  File.open("#{cardfile}.html", "w") do |f|
    f.puts <<-EOS
      <div class="card mb-3">
        <div class="card-body">
          <h5 class="card-title">
            <button type="button" class="btn btn-primary" data-toggle="collapse" data-target="##{tag}">+</button>
            <a href="javascript: void(0)" 
               onclick="javascript:open_main('#{url}')" 
               style="text-decoration: none; color: black"> #{card_title}</a>
          </h5>
          <div class="collapse" id="#{tag}">
    EOS
    log!(str: "Writing data pairs to #{cardfile}.html", pwd: true)
    local = _local_tag?(tag)
    pairs.each do |file, title| 
      url = file
      type, title = page_type(tag, title)
      case type
        when :local;   url_ref = _widget_card(file, tag)  # local always frameable
        when :frame;   url_ref = _main(file)              # remote, frameable
        when :noframe; url_ref = _blank(file)             # remote, not frameable
      end
      anchor = %[<a #{url_ref}>#{title}</a>]
      wrapper = %[<li class="list-group-item">#{anchor}</li>]
      f.puts wrapper
    end
    _include_file cardfile+".html"
    f.puts <<-EOS
          </div>
        </div>
      </div>
    EOS
  end
end

def _local_tag?(tag)
  case tag.to_sym
    when :pages
      true
    when :news, :links
      false
  else
    true  # Hmmm...
  end
end

def page_type(tag, title)
  yesno = "yes"
  yesno, title = title.split(/, */) if title =~ /^[yes|no]/
  local = _local_tag?(tag)
  frameable = (yesno == "yes")
  if local
    return [:local, title]
  elsif frameable 
    return [:frame, title]
  else
    return [:noframe, title]
  end
end

def _write_main_pages(mainfile, pairs, card_title, tag)
  local = _local_tag?(tag)
  pieces = @blog.view.dir/"themes/standard/widgets"/tag/:pieces
  main_head = xlate! cwd: pieces, src: "main-head.lt3"
  main_tail = xlate! cwd: pieces, src: "main-tail.lt3"
  # ^ make into methods in pages.rb or whatever?
                    
  File.open("#{mainfile}.html", "w") do |f|
    f.puts main_head
    pairs.each do |file, title| 
      type, title = page_type(tag, title)
      title = title.gsub(/\\/, "")  # kludge
      case type
        when :local;   url_ref = _widget_main(file, tag)  # local always frameable
        when :frame;   url_ref = "href = '#{file}'"       # local always frameable
        when :noframe; url_ref = _blank(file)             # local always frameable
      end
      css = "color: #8888FF; text-decoration: none; font-size: 24px; font-family: verdana"
      f.puts %[<a style="#{css}" #{url_ref}>#{title}</a> <br>]
    end
    f.puts main_tail
  end
end

def _write_main(mainfile, pairs, card_title, tag)
  log!(str: "Creating #{mainfile}.html", pwd: true)

  if tag == "pages"   # temporary experiment
    _write_main_pages(mainfile, pairs, card_title, tag)
    return
  end

  local = _local_tag?(tag)
  setvar "card.title", card_title
  File.open("#{mainfile}.html", "w") do |f|
    _html_body(f) do
      f.puts "<h1>#{card_title}</h1>"
      pairs.each do |file, title| 
        type, title = page_type(tag, title)
        title = title.gsub(/\\/, "")  # kludge
        case type
          when :local;   url_ref = _widget_main(file, tag)  # local always frameable
          when :frame;   url_ref = "href = '#{file}'"       # local always frameable
          when :noframe; url_ref = _blank(file)             # local always frameable
        end
        css = "color: #8888FF; text-decoration: none; font-size: 24px; font-family: verdana"
        f.puts %[<a style="#{css}" #{url_ref}>#{title}</a> <br>]
      end
    end
  end
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

def _write_metadata
  File.write("teaser.txt", @meta.teaser)
  fields = [:num, :title, :date, :pubdate, :views, :tags]
  fname2 = "metadata.txt"
  f2 = File.open(fname2, "w") do |f2| 
    fields.each {|fld| f2.puts "#{fld}: #{@meta.send(fld)}" }
  end
end

def _post_lookup(postid)    # side-effect
  # .. = templates, ../.. = views/thisview
  slug = title = date = teaser_text = nil

  dir_posts = @vdir/:posts
  posts = Dir.entries(dir_posts).grep(/^\d\d\d\d/).map {|x| dir_posts/x }
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

def _var(name)  # FIXME scope issue!
  ::Livetext::Vars[name] || "[:#{name} is undefined]"
end

def _main(url)
  %[href="javascript: void(0)" onclick="javascript:open_main('#{url}')"]
end

def _blank(url)
  %[href='#{url}' target='blank']
end

def _widget_main(url, tag)
  %[href="#{url}"]
end

def _widget_card(url, tag)
  url2 = :widgets/tag/url
  %[href="javascript: void(0)" onclick="javascript:open_main('#{url2}')"]
end

