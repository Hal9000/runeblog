# Custom code for 'pages' widget

# How to update repl code?

class ::RuneBlog::Widget
  class Pages
    Type, Title = "pages", "My Pages"

    def initialize(repo)
      @blog = repo
      @datafile = "list.data"
      @lines = _get_data(@datafile)
      @data = @lines.map {|x| x.chomp.split(/, */, 2) }
    end

    def build
      # build child pages
      children = Dir["*.lt3"] - ["pages.lt3"]
      children.each do |child|
        dest = child.sub(/.lt3$/, ".html")
        preprocess src: child, dst: dest
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
      css = "body { font-family: verdana }"
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

    def manage
      dir = @blog.view.dir/"widgets/pages"
      # Assume child files already generated (and list.data??)
      data = dir/"list.data"
      lines = _get_data?(data)
      hash = {}
      lines.each do |line|
        url, name = line.chomp.split(",")
        source = url.sub(/.html$/, ".lt3")
        hash[name] = source
      end
      new_item = "[New page]"
      num, fname = STDSCR.menu(title: "Edit page:", items: hash.keys + [new_item])
      return if fname.nil?
      if fname == new_item
        print "Page title:  "
        title = RubyText.gets
        title.chomp!
        print "File name (.lt3): "
        fname = RubyText.gets
        fname << ".lt3" unless fname.end_with?(".lt3")
        fhtml = fname.sub(/.lt3$/, ".html")
        File.open(data, "a") {|f| f.puts "#{fhtml},#{title}" }
        new_file = dir/fname
        File.open(new_file, "w") do |f|
          f.puts "<h1>#{title}</h1>\n\n\n "
          f.puts ".backlink"
        end
        edit_file(new_file)
      else
        target = hash[fname]
        edit_file(dir/target)
      end
    end

    def edit_menu
    end

    def refresh
    end
  end
end
