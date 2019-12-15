require 'ostruct'
require 'pp'
require 'date'
require 'find'

require 'runeblog'
require 'pathmagic'
require 'processing'


def init_liveblog    # FIXME - a lot of this logic sucks
  dir = Dir.pwd.sub(/\.blogs.*/, "")
  @blog = nil
  Dir.chdir(dir) { @blog = RuneBlog.new }
  @root = @blog.root
  @view = @blog.view
  @view_name = @blog.view.name unless @view.nil?
  @vdir = @blog.view.dir rescue "NONAME"
  @version = RuneBlog::VERSION
  @theme = @vdir/:themes/:standard
end

##################
# "dot" commands
##################

def dropcap
  # Bad form: adds another HEAD
  text = _data
  _out " "
  letter = text[0]
  remain = text[1..-1]
  _out %[<div class='mydrop'>#{letter}</div>]
  _out %[<div style="padding-top: 1px">#{remain}]
end

def post
  @meta = OpenStruct.new
  @meta.num = _args[0]
  _out "  <!-- Post number #{@meta.num} -->\n "
end

def post_trailer
  perma = _var("publish.proto") + "://" + _var("publish.server") +
          "/" + _var("publish.path") + "/permalink/" + _var("post.aslug") + 
          ".html"
  tags = _var("post.tags")
  if tags.empty?
    taglist = ""
  else
    taglist = "Tags: #{tags}"
  end
  _out <<~HTML
  <table width=100%><tr>
    <td width=10%><a style="text-decoration: none" href="javascript:history.go(-1)">[Back]</a></td>
    <td width=10%><a style="text-decoration: none" href="#{perma}"> [permalink] </a></td>
    <td width=80% align=right><font size=-3>#{taglist}</font></td></tr></table>
  HTML
  # damned syntax highlighting
end

def faq
  @faq_count ||= 0
  _out "<br>" if @faq_count == 0
  @faq_count += 1
  ques = _data.chomp
  ans  = _body_text
  id = "faq#@faq_count"
  _out %[&nbsp;<a data-toggle="collapse" href="##{id}" role="button" aria-expanded="false" aria-controls="collapseExample"><font size=+3>&#8964;</font></a>]
  _out %[&nbsp;<b>#{ques}</b>]
  _out %[<div class="collapse" id="#{id}"><br><font size=+1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;#{ans}</font></div>\n]
  _out "<br>" unless @faq_count == 1
  _optional_blank_line
end

def backlink
  _out %[<br><a href="javascript:history.go(-1)">[Back]</a>]
end

def code
  lines = _body_text
  _out "<font size=+1><pre>\n#{lines}\n</pre></font>"
end

def _read_navbar_data
  dir = @blog.root/:views/@blog.view/"themes/standard/banner/"
  datafile = dir/"list.data"
  File.readlines(datafile)
end

def banner
  count = 0
  span = 1
  @bg = "white"  # outside loop
  wide = nil
  high = 250
  str2 = ""
  navbar = nil
  lines = _body.to_a

  lines.each do |line|
    count += 1
    tag, *data = line.split
    data ||= []
    case tag
      when "width"
        wide = data[0]
      when "height"
        high = data[0]
      when "bgcolor"
        @bg = data[0] || "white"
      when "image"
        image = data[0] || "banner.jpg"
        image = "banner"/image
        wide = data[0]
        width = wide ? "width=#{wide}" : "" 
        str2 << "      <td colspan=#{span}><img src=#{image} #{width} height=#{high}></img></td>" + "\n"
      when "svg_title"
        stuff, hash = _svg_title(*data)
        wide = hash["width"]
        str2 << "      <td colspan=#{span} width=#{wide}>#{stuff}</td>" + "\n"
      when "text"
        data[0] ||= "top.html"
        file = "banner"/data[0]
        str2 << "<td colspan=#{span}>" + File.read(file) + "</td>" + "\n"
      when "navbar"
        dir = @blog.root/:views/@blog.view/"themes/standard/banner/" + "\n"
        _make_navbar  # horiz is default
        file = "banner/navbar.html"
        navbar = File.read(file)
        # str2 << "<td colspan=#{span}><div style='text-align: center'>#{stuff}</div></td>" + "\n"
      when "vnavbar"
        dir = @blog.root/:views/@blog.view/"themes/standard/banner/"
        _make_navbar(:vert)
        file = "banner/vnavbar.html"
        navbar = File.read(file)
        # str2 << "<td colspan=#{span}>" + File.read(file) + "</td>" + "\n"
      when "break"
         span = count - 1
         str2 << "  </tr>\n  <tr>"  + "\n"
    else
      str2 << "        '#{tag}' isn't known" + "\n"
    end
  end
  _out "<table width=100% height=#{high} bgcolor=##{@bg}>"
  _out "  <tr>"
  _out str2
  _out "  </tr>"
  _out "</table>"
  _out navbar if navbar
rescue => err
  STDERR.puts "err = #{err}"
  STDERR.puts err.backtrace.join("\n")
  gets
end

def _parse_colon_args(args, hash)  # really belongs in livetext
  h2 = hash.dup
  e = args.each
  loop do
    arg = e.next.chop.to_sym
    raise "_parse_args: #{arg} is unknown" unless hash.keys.include?(arg)
    h2[arg] = e.next
  end
  h2 = h2.reject {|k,v| v.nil? }
  h2.each_pair {|k, v| raise "#{k} has no value" if v.empty? }
  h2
end

def _get_arg(name, args)  # really belongs in livetext
  raise "(#{name}) Expected an array" unless args.is_a? Array
  raise "(#{name}) Expected an arg" if args.empty?
  raise "(#{name}) Too many args: #{args.inspect}" if args.size > 1
  val = args[0]
  raise "Expected an argument '#{name}'" if val.nil?
  val
end

def _svg_title(*args)
  width    = 330
  height   = 100
  bgcolor  = "blue"
  style    = nil
  size     = ""
  font     = "sans-serif"
  color    = "white"
  xy       = "5,5"
  align    = "center"
  style2   = nil
  size2    = ""
  font2    = "sans-serif"
  color2   = "white"
  xy2      = "5,5"
  align2   = "center"

  e = args.each
  hash = {}
  loop do
    arg = e.next
    arg = arg.chop
    case arg   # can give runtime error if arg missing
      when "width";    width    = e.next
      when "height";   height   = e.next
      when "bgcolor";  bgcolor  = e.next
      when "style";    style    = e.next
      when "size";     size     = e.next
      when "font";     font     = e.next
      when "color";    color    = e.next
      when "xy";       xy       = e.next
      when "align";    align    = e.next
      when "style2";   style2   = e.next
      when "size2";    size2    = e.next
      when "font2";    font2    = e.next
      when "color2";   color2   = e.next
      when "xy2";      xy2      = e.next
      when "align2";   align2   = e.next
    end
  end
  x, y = xy.split(",")
  x2, y2 = xy2.split(",")
  hash["x"]       = x
  hash["y"]       = y
  hash["x2"]      = x2
  hash["y2"]      = y2
  hash["width"]   = width
  hash["height"]  = height
  hash["bgcolor"] = bgcolor
  hash["style"]   = style
  hash["size"]    = size
  hash["font"]    = font
  hash["color"]   = color
  hash["xy"]      = xy
  hash["align"]   = align
  hash["style2"]  = style2
  hash["size2"]   = size2
  hash["font2"]   = font2
  hash["color2"]  = color2
  hash["align2"]  = align2
  result = <<~HTML
    <svg width="#{width}" height="#{height}"
         viewBox="0 0 #{width} #{height}">
      <style>
        .title    { font: #{style} #{size} #{font}; fill: #{color} }
        .subtitle { font: #{style2} #{size2} #{font2}; fill: #{color2} }
      </style>
      <rect x="10" y="10" rx="10" ry="10" width="#{width-20}" height="#{height-20}" fill="#{bgcolor}"/>
      <text text-anchor="#{align}"  x="#{x}" y="#{y}" class="title">#{Livetext::Vars[:blog]} </text>
      <text text-anchor="#{align2}" x="#{x2}" y="#{y2}" class="subtitle">#{Livetext::Vars["blog.desc"]} </text>
    </svg>
  HTML
  [result, hash]
end

def svg_title_SOON
  tstyle = tsize = tfont = tcolor = txy = talign = nil
  t2style = t2size = t2font = t2color = t2xy = t2align = nil
  wide, high, hue = 450, 150, "white"
  _body do |line|
    count += 1
    tag, *data = line.split
    data ||= []
    title_params = {style: nil, size: "", font: "sans-serif", color: "white",
                    xy: "5,5", align: "left"}
    case tag
      when "title";   
        hash = _parse_colon_args(data, title_params)
        tstyle, tsize, tfont, tcolor, txy, talign = 
          hash.values_at(:tstyle, :tsize, :tfont, :tcolor, :txy, :talign)
        tx, ty = txy.split(",")
      when "title2";  
        hash = _parse_colon_args(data, title_params)
        t2style, t2size, t2font, t2color, t2xy, t2align =
          hash.values_at(:t2style, :t2size, :t2font, :t2color, :t2xy, :t2align)
        t2x, t2y = t2xy.split(",")
      when "width";   wide = _get_arg(:width, data)
      when "height";  high = _get_arg(:height, data)
      when "bgcolor"; hue  = _get_arg(:bgcolor, data)
    end
  end
  <<~HTML
    <svg width="#{wide}" height="#{high}"
         viewBox="0 0 #{wide} #{high}">
      <style>
        .title    { font: #{tstyle} #{tsize} #{tfont}; fill: #{tcolor} }
        .subtitle { font: #{t2style} #{t2size} #{t2font}; fill: #{t2color} }
      </style>
      <rect x="0" y="0" rx="10" ry="10" width="#{wide}" height="#{height}" fill="#{bgcolor}"/>
      <text text-anchor="#{talign}"  x="#{tx}" y="#{tx}" class="title">$blog </text>
      <text text-anchor="#{t2align}" x="#{t2x}" y="#{t2y}" class="subtitle">$blog.desc </text>
    </svg>
  HTML
end

def quote
  _passthru "<blockquote>"
  _passthru _body.join(" ")
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

### inset

def inset
  lines = _body
  box = ""
  output = []
  lines.each do |line| 
    line = line
    case line[0]
      when "/"  # Only into inset
        line[0] = ' '
        box << line
        line.replace(" ")
      when "|"  # Into inset and body
        line[0] = ' '
        box << line
        output << line
    else  # Only into body
      output << line 
    end
  end
  lr = _args.first
  wide = _args[1] || "25"
  stuff = "<div style='float:#{lr}; width: #{wide}%; padding:8px; padding-right:12px'>"
  stuff << '<b><i>' + box + '</i></b></div>'
  _out "</p>"   #  kludge!! nopara
  0.upto(2) {|i| _passthru output[i] }
  _passthru stuff
  3.upto(output.length-1) {|i| _passthru output[i] }
  _out "<p>"  #  kludge!! para
  _optional_blank_line
end

def title
  raise "'post' was not called" unless @meta
  title = @_data.chomp
  @meta.title = title
  setvar :title, title
  # FIXME refactor -- just output variables for a template
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
  _debug "data = #{_args}"  # verify only valid views?
  pinned = @_args
  @meta.pinned = pinned
  pinned.each do |pinview|
    dir = @blog.root/:views/pinview/"themes/standard/widgets/pinned/"
    datafile = dir/"list.data"
    pins = File.exist?(datafile) ? File.readlines(datafile) : []
    pins << "#{@meta.num} #{@meta.title}\n"
    pins.uniq!
    File.open(datafile, "w") {|out| pins.each {|pin| out.puts pin } }
  end
  _optional_blank_line
rescue => err
  STDERR.puts "err = #{err}"
  STDERR.puts err.backtrace.join("\n")
  gets
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
  text = _body_text
  @meta.teaser = text
  setvar :teaser, @meta.teaser
  if _args[0] == "dropcap"   # FIXME doesn't work yet!
    letter, remain = text[0], text[1..-1]
    _out %[<div class='mydrop'>#{letter}</div>]
    _out %[<div style="padding-top: 1px">#{remain}] + "\n"
  else
    _out @meta.teaser + "\n"
  end
end

def finalize
  return unless @meta
  return @meta if @blog.nil?

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
#              "style"          => %[<link rel="stylesheet" href="etc/blog.css">],
# ^ FIXME
               "feed"           => %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}/feed.xml" title="#{_var(:blog)}">],
               "favicon"        => %[<link rel="shortcut icon" type="image/x-icon" href="etc/favicon.ico">\n <link rel="apple-touch-icon" href="etc/favicon.ico">]
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
        result["style"] = %[<link rel="stylesheet" href="etc/#{remain}">]
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

def _make_class_name(app)
  if app =~ /[-_]/
    words = app.split(/[-_]/)
    name = words.map(&:capitalize).join
  else
    name = app.capitalize
  end
  return name
end

def _load_local(widget)
  Dir.chdir("widgets/#{widget}") do
    rclass = _make_class_name(widget)
    found = (require("./#{widget}") if File.exist?("#{widget}.rb"))
    code = found ? ::RuneBlog::Widget.class_eval(rclass) : nil
    code
  end
rescue => err
  STDERR.puts err.to_s
  STDERR.puts err.backtrace.join("\n")
  exit
end

# def pinned_rebuild
#   view = @blog.view
#   view = _args[0] unless _args.empty?
#   Dir.chdir(@blog.root/:views/view/"themes/standard/") do
#     wtag = "widgets/pinned"
#     code = _load_local("pinned")
#     if code 
#       Dir.chdir(wtag) do 
#         widget = code.new(@blog)
#         widget.build
#       end
#       # _include_file wtag/"pinned-card.html"
#     end
#   end
# end

def _handle_standard_widget(tag)
  wtag = :widgets/tag
  code = _load_local(tag)
  if code 
    Dir.chdir(wtag) do 
      widget = code.new(@blog)
      widget.build
    end
  end
end

def sidebar
  _debug "--- handling sidebar\r"
  if _args.include? "off"
    _body { }  # iterate, do nothing
    return 
  end

  _out %[<div class="col-lg-3 col-md-3 col-sm-3 col-xs-12">]

  standard = %w[pinned pages links news]

  _body do |token|
    tag = token.chomp.strip.downcase
    wtag = :widgets/tag
    raise "Can't find #{wtag}" unless Dir.exist?(wtag)
    tcard = "#{tag}-card.html"

    case
      when standard.include?(tag)
        _handle_standard_widget(tag)
      when tag == "ad"
        num = rand(1..4)
        img = "widgets/ad/ad#{num}.png"
        src, dst = img, @root/:views/@view_name/"remote/widgets/ad/"
        system!("cp #{src} #{dst}")   # , show: true)
        File.open(wtag/"vars.lt3", "w") do |f| 
          f.puts ".set ad.image = #{img}"
        end
        preprocess cwd: wtag, src: tag, dst: tcard, force: true # , debug: true # , deps: depend 
    end

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
end

###


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

def vnavbar
  str = _make_navbar(:vert)
end

def hnavbar
  str = _make_navbar  # horiz is default
end

def navbar
  str = _make_navbar  # horiz is default
end

def _make_navbar(orient = :horiz)
  vdir = @root/:views/@blog.view
  title = _var(:blog)

  if orient == :horiz
    name = "navbar.html"
    li1, li2 = "", ""
    extra = "navbar-expand-lg" 
    list1 = list2 = ""
  else
    name = "vnavbar.html"
    li1, li2 = '<li class="nav-item">', "</li>"
    extra = ""
    list1, list2 = '<l class="navbar-nav mr-auto">', "</ul>"
  end
  
#      <!-- FIXME weird bug here!!! -->
  start = <<-HTML
   <table><tr><td>
   <nav class="navbar #{extra} navbar-light bg-light">
      #{list1}
  HTML
  finish = <<-HTML
      #{list2}
    </nav>
    </td></tr></table>
  HTML

  html_file = @blog.root/:views/@blog.view/"themes/standard/banner"/name
  output = File.new(html_file, "w")
  output.puts start
  lines = _read_navbar_data
  lines = ["index  Home"] + lines  unless _args.include?("nohome")
  lines.each do |line|
    basename, cdata = line.chomp.strip.split(" ", 2)
    full = :banner/basename+".html"
    href_main = _main(full)
    if basename == "index"  # special case
      output.puts %[#{li1} <a class="nav-link" href="index.html">#{cdata}<span class="sr-only">(current)</span></a> #{li2}]
    else
      dir = @blog.root/:views/@blog.view/"themes/standard/banner"
      preprocess cwd: dir, src: basename, dst: vdir/"remote/banner"/basename+".html" # , debug: true
      output.puts %[#{li1} <a class="nav-link" #{href_main}>#{cdata}</a> #{li2}]
    end
  end
  output.puts finish
  output.close
  return File.read(html_file)
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
  fields = [:num, :title, :date, :pubdate, :views, :tags, :pinned]
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

