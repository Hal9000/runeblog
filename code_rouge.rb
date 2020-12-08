require 'rouge'

def ruby
  theme = :Github  # default
  lines = _body(true)  # raw
  source = lines.join("\n")
  formatter = Rouge::Formatters::HTML.new
  lexer = Rouge::Lexers::Ruby.new
  body = formatter.format(lexer.lex(source))

# css = Rouge::Themes.const_get(theme.to_s).render(scope: '.highlight')
# added = ".highlight { font-family: courier; white-space: pre }"

  key = '%6d' % rand(10**6)
  html_file = "#{RuneBlog.blog.view.dir}/remote/fragment-#{key}-rb.html"
  File.open(html_file, "w") do |output|
    output.puts <<~HTML
      <html>
        <head><link rel="stylesheet" href="etc/github.css"></head>
        <body class="highlight">
#{body}
        </body>
      </html>
    HTML
  end

  _out <<~HTML
    <div class="highlight">
#{body}
    </div>
    <br>
  HTML

  return

  iheight = lines.size * 25
  _out <<~HTML
    <center>
      <iframe width=90% height=#{iheight} src='#{File.basename(html_file)}'></iframe>
    </center>
    <br>
  HTML
end


