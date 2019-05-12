def var(name)
  Livetext::Vars[name]  # FIXME improve later
end

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

def all_teasers
  open = <<-HTML
      <section class="posts">
  HTML
  close = <<-HTML
      </section>
  HTML
  _out open
  # Call teaser here (multiple times)...
  40.times { _out "Lots of stuff missing here. " }
  _out close
end

def teaser
  ids = _args
  ids.each do |id|
    post = SOMEHOW_LOOKUP(id)
    text = <<-HTML
      <div class="post">
        <h1 class="post-title"> <a href="NNNN.html">POST_TITLE</a> </h1>
        <span class="post-date mt-1 mb-1">PUBDATE</span>
        <p>POST_TEASER</p>
        <p><a class="btn btn-light" href="NNNN.html">Keep Reading</a></p>
        <hr>
      </div>
    HTML
    _out text + "\n "
  end
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
  title = var(:title)
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

