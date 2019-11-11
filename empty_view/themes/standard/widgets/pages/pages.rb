# Custom code for 'pages' widget

# How to update repl code?

class ::RuneBlog::Widget
  class Pages
    Type, Title = "pages", "Pages"

    def initialize(repo)
      @blog = repo
      @datafile = "list.data"
      @lines = File.readlines(@datafile)
      @data = @lines.map {|x| x.chomp.split(/, */, 2) }
    end

    def build
      # build child pages
      children = Dir["*.lt3"] - ["pages.lt3"]
      children.each do |child|
        dest = child.sub(/.lt3$/, ".html")
        xlate src: child, dst: dest
      end
      write_main
      write_card
    end

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

    def write_main
      css = "* { font-family: verdana }"
      card_title = Title
      File.open("#{Type}-main.html", "w") do |f|     
        _html_body(f, css) do
          f.puts "<h1>#{card_title}</h1><br><hr>"
          url_ref = nil
          @data.each do |url, title|
            url_ref = "href = '#{url}'"
            css = "color: #8888FF; text-decoration: none; font-size: 21px"
            f.puts %[<a style="#{css}" #{url_ref}>#{title}</a> <br>]
          end
        end
      end
    end

    def write_card
      tag = Type
      url = :widgets/tag/tag+"-main.html"
      card_title = "Pages"  # FIXME
      cardfile = "#{Type}-card"
      File.open("#{cardfile}.html", "w") do |f|
        f.puts <<-EOS
          <div class="card mb-3">
            <div class="card-body">
              <h5 class="card-title">
                <button type="button" class="btn btn-primary" data-toggle="collapse" data-target="##{tag}">+</button>
                <a href="javascript: void(0)" 
                   onclick="javascript:open_main('#{url}')" 
                   style="text-decoration: none; color: black">#{card_title}</a>
              </h5>
              <div class="collapse" id="#{tag}">
        EOS
        @data.each do |url2, title|
          f.puts "<!-- #{[url2, title].inspect} -->"
          url3 = :widgets/tag/url2
          f.puts "<!-- url3 = #{url3.inspect} -->"
          url_ref = %[href="javascript: void(0)" onclick="javascript:open_main('#{url3}')"]
          anchor = %[<a #{url_ref}>#{title}</a>]
          wrapper = %[<li class="list-group-item">#{anchor}</li>]
          f.puts wrapper
        end
        f.puts <<-EOS
              </div>
            </div>
          </div>
        EOS
      end
    end

    def edit_menu
    end

    def refresh
    end
  end
end
