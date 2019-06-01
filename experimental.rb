class Livetext::Functions

  def _var(name)
    ::Livetext::Vars[name] || "[:#{name} is undefined]"
  end


  def link
    file, cdata = self.class.param.split("||", 2)
    %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}#{file}" title="#{_var(:title)}">]
  end

end

###############

def _var(name)  # FIXME later
  ::Livetext::Vars[name] || "[:#{name} is undefined]"
end

def head
  defaults = {}
  defaults = { "charset"        => %[<meta charset="utf-8">],
               "http-equiv"     => %[<meta http-equiv="X-UA-Compatible" content="IE=edge">],
               "title"          => %[<title>\n  #{_var(:title)} | #{_var(:desc)}\n  </title>],
               "generator"      => %[<meta name="generator" content="Runeblog v #{0.1}">],  # FIXME
               "og:title"       => %[<meta property="og:title" content="#{_var(:title)}">],
               "og:locale"      => %[<meta property="og:locale" content="en_US">],
               "description"    => %[<meta name="description" content="#{_var(:desc)}">],
               "og:description" => %[<meta property="og:description" content="#{_var(:desc)}">],
               "linkc"          => %[<link rel="canonical" href="#{_var(:host)}">],
               "og:url"         => %[<meta property="og:url" content="#{_var(:host)}">],
               "og:site_name"   => %[<meta property="og:site_name" content="#{_var(:title)}">],
               "style"          => %[<link rel="stylesheet" href="../assets/application.css">],
               "feed"           => %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}/feed.xml" title="#{_var(:title)}">],
               "favicon"        => %[<link rel="shortcut icon" type="image/x-icon" href="../assets/favicon.ico">\n <link rel="apple-touch-icon" href="../assets/favicon.ico">]
             }
  result = {}
  lines = _body
  lines.each do |line|
    line.chomp
    word, remain = line.split(" ", 2)
    case word
      when "viewport"
        result["viewport"] = %[<meta name="viewport" content="#{remain}">]
      when "script"
        file = remain
        text = File.read(file)
        result["script"] = Livetext.new.transform(text)
      when "style"
        result["style"] = %[<link rel="stylesheet" href="('/assets/#{remain}')">]
      # Later: allow other overrides
      when ""; break
      else
        puts "Unknown tag '#{word}'"
    end
  end
  hash = defaults.dup.update(result)  # FIXME collisions?
  _out "<html lang=en_US>"
  _out "<head>"
  hash.each_value {|x| _out "  " + x }
  _out "</head>"
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
      puts "=== meta error?"
    end
    arg = enum.next
  end
  str << ">"
  _out str
end

def main
  _out %[<div class="col-lg-9 col-md-9 col-sm-9 col-xs-12">]
  all_teasers    # FIXME does nothing yet
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
  posts = nil
  Dir.chdir("../../..") do
    posts = Dir.entries(".").grep(/^\d\d\d\d/).select {|x| File.directory?(x) }
    # directories that start with four digits
    posts = posts.sort {|a, b| b.to_i <=> a.to_i }  # sort descending
  end
  posts[0..19]  # return 20 at most
end

def all_teasers
  open = <<-HTML
      <section class="posts">
  HTML
  close = <<-HTML
      </section>
  HTML
  _out open
  # FIXME: Now do the magic...
  posts = _find_recent_posts
# STDERR.puts "--- after frp: posts = #{posts.inspect}"
  wanted = [5, posts.size].min  # estimate how many we want?
  enum = posts.each
  wanted.times do
    postid = enum.next
# STDERR.puts "--- allt: postid = #{postid.inspect}"
    postid = postid.to_i
    _teaser(postid)
  end
# 40.times { _out "Lots of stuff missing here. " }
  _out close
end

def _post_lookup(postid)
  # .. = templates, ../.. = views/thisview
  slug = title = date = teaser_text = nil

  posts = Dir.entries(".").grep(/^\d\d\d\d/).select {|x| File.directory?(x) }
  post = posts.select {|x| x.to_i == postid }
  raise "Error: More than one post #{postid}" if post.size > 1
  postdir = post.first
  fname = "#{postdir}/teaser.txt"
  teaser_text = File.read(fname).chomp
  # FIXME dumb hacks...
  mdfile = "#{postdir}/metadata.txt"
  lines = File.readlines(mdfile)
  title = lines.grep(/title:/).first[7..-1].chomp
  date  = lines.grep(/pubdate:/).first[9..-1].chomp
  slug  = postdir
  [slug, title, date, teaser_text]
end

def _interpolate(str, context)   # FIXME move this later
  wrapped = "%[" + str.dup + "]"  # could fail...
  eval(wrapped, context)
end

def _teaser(slug)
  id = slug.to_i
  text = nil
  @_post_entry ||= File.read("_postentry.lt3")
  slug = title = date = teaser_text = nil
  Dir.chdir("../../..") do
    slug, title, date, teaser_text = _post_lookup(id)
  end
# STDERR.puts "--- _teaser looked up: #{[slug, title, date, teaser_text].inspect}"
  vdir = File.expand_path("../../..")
  url = "#{vdir}/#{slug}.html"
STDERR.puts "Making url... pwd = #{Dir.pwd}    url = #{url}"
# STDERR.puts :_teas01
    date = Date.parse(date)
    date = date.strftime("%B %e<br>%Y")
    text = _interpolate(@_post_entry, binding)
# STDERR.puts "Hmm, pwd = #{Dir.pwd}"
    File.write("../../../generated/#{slug}.html", text)
# STDERR.puts "-- _teaser: TEXT = #{text.inspect}"
  _out text
end

def card_iframe
  title = _data
  lines = _body
  url = lines[0].chomp
  stuff = lines[1..-1].join(" ")  # FIXME later
  text = <<-HTML
        <div class="card mb-3">
          <div class="card-body">
            <h5 class="card-title">#{title}</h5>
            <iframe src="#{url}" #{stuff} 
                    style="border: 0" height="350" 
                    frameborder="0" scrolling="no">
            </iframe>
          </div>
        </div>
  HTML
  _out text
end

def card1
  card_title = _data
  lines = _body
  lines.map!(&:chomp)
  card_text = lines[0]
  url, target, classname, cdata = lines[1].split(",", 4)
  text = <<-HTML
    <div class="card bg-dark text-white mb-3">
      <div class="card-body">
        <h5 class="card-title">#{card_title}</h5>
        <p class="card-text">#{card_text}</p>
        <a href="#{url}" target="#{target}" class="#{classname}">#{cdata}</a>
      </div>
    </div>
  HTML
  _out text + "\n "
end

def card2
  card_title = _data
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
end

def navbar
  title = _var(:title)
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

