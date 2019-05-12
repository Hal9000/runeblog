class Livetext::Functions

  def _var(name)
    ::Livetext::Vars[name]
  end

  def svg
    file = self.class.param
    File.read(file+".svg")
  end

  def checkbox
    id = self.class.param
    %[<input type="checkbox" id="#{id}" class="#{id}">]
  end

  def wrap
    stuff = self.class.param
    stuff = FormatLine.var_func_parse(stuff)
    %[<div class="wrapper">\n#{stuff}\n</div>]
  end

  def wrap4
    string = self.class.param
    string = FormatLine.var_func_parse(string)
    params = string.split("||", 5)
    contents, aclass, rel, href, cdata = *params
    %[<div class="wrapper"><a class="#{aclass}" rel="#{rel}" href="#{href}">#{cdata}</a>\n] + contents + "\n</div>"
  end

  def h2
    id, cdata = self.class.param.split("||", 2)
    %[<h2 class="#{id}">#{cdata}</h2>]
  end

  def link
    file, cdata = self.class.param.split("||", 2)
    %[<link type="application/atom+xml" rel="alternate" href="#{_var(:host)}#{file}" title="#{_var(:title)}">]
  end

  def p 
    text, link = self.class.param.split("||", 2)
    %[<p class="rss-subscribe">#{text}\n #{link}</p>]
  end

  def divh
    head, tag, sub = self.class.param.split("||", 3)
    %[<div class="home">\n #{head}\n #{tag}\n #{sub}\n </div>]
  end
end

###############

def _hwf(h, w, f)
  f ||= "none"
  lines = ["height: #{h}px", "width:  #{w}%", "float:  #{f}"]
  lines.each {|x| _out "  #{x};" }
end

def _css(name, h, w, f)
  name = "." + name
  _out name
  _out "{"
  _hwf h, w, f
  _out "}\n "
end

def _mcss(names, stuff)
  names = [names] unless names.is_a? Array
  names.map! {|x| "." + x }
  _out names.join(", ")
  _out "{"
  stuff.each {|x| _out "  #{x};" }
  _out "}\n "
end

def css
  line = _data.chomp
  name, h, w, f = line.split
  _css(name, h, w, f)
end

def mcss
  line = _data.chomp
  names, stuff = line.split("|")
  names = names.split
  stuff = stuff.split(";")
  _mcss(names, stuff)
end

def see_vars
  puts "####### Vars ="
  Livetext::Vars.each_pair {|k,v| puts "#{k.inspect}  => #{v.inspect}" }
  puts "#######"
end

def site_header
  role, text = *_args
  text = FormatLine.var_func_parse(text)
  _out %[<header class="site-header" role="#{role}">\n] + 
         text + "\n</header>"
end

def main
  stuff = _data
  stuff = FormatLine.var_func_parse(stuff)
  _out %[<main class="page-content" aria-label="Content">\n] +
          stuff + "\n</main>"
end

def site_footer
  _out %[<footer class="site-footer h-card"> </footer> </body> </html>]
end

def var(name)
  Livetext::Vars[name]
end

def svg
  file = _args.first
  _out File.read(file + ".svg")
end

def nav
  nclass, cb = _args
  text = <<-HTML
  <div class="#{nclass}">
    <input type="checkbox" id="#{cb}" class="#{cb}">
    <label for="#{nclass}">
      <span class="menu-icon">    <!-- FIXME -->
  HTML
  text2 = <<-HTML
      </span>
    </label>
  </nav>
  HTML
  _out text
  _body {|x| _out x }
  _out text2
end

def head
  defaults = {}
  defaults = { "charset"        => %[<meta charset="utf-8">],
               "http-equiv"     => %[<meta http-equiv="X-UA-Compatible" content="IE=edge">],
               "title"          => %[<title>\n  #{var(:title)} | #{var(:desc)}\n  </title>],
               "generator"      => %[<meta name="generator" content="Runeblog v #{0.1}">],  # FIXME
               "og:title"       => %[<meta property="og:title" content="#{var(:title)}">],
               "og:locale"      => %[<meta property="og:locale" content="en_US">],
               "description"    => %[<meta name="description" content="#{var(:desc)}">],
               "og:description" => %[<meta property="og:description" content="#{var(:desc)}">],
               "linkc"          => %[<link rel="canonical" href="#{var(:host)}">],
               "og:url"         => %[<meta property="og:url" content="#{var(:host)}">],
               "og:site_name"   => %[<meta property="og:site_name" content="#{var(:title)}">],
               "style"          => %[<link rel="stylesheet" href="('/assets/main.css')">],
               "feed"           => %[<link type="application/atom+xml" rel="alternate" href="#{var(:host)}/feed.xml" title="#{var(:title)}">]
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

def diva
  # .diva trigger page-link /about/ About this blog
  dclass, aclass, href, cdata =  _data.split(" ", 4)
  # ["trigger", "page-link", "/about/", "About this blog"]
  _out %[<div class="#{dclass}"><a class="#{aclass}" href="#{href}">#{cdata}</a></div>]
end

