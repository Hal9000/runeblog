# Custom code for 'pages' widget

# How to update repl code?

class ::RuneBlog::Widget
  class Pages
    Type = "pages"

    def initialize(repo)
      @blog = repo
      @datafile = "list.data"
    end

    def build
      # build child pages
      children = Dir["*.lt3"] - ["pages.lt3"]
      children.each do |child|
        dest = child.sub(/.lt3$/, ".html")
        xlate src: child, dst: dest  # , debug: true
      end
      @lines = File.readlines(@datafile)
      write_main
      write_card
    end

    def write_main
      @data = @lines.map! {|x| x.chomp.split(/, */, 3) }
      css = "* { font-family: verdana }"
      card_title = "Pages"  # FIXME
      File.open("#{Type}-main.html", "w") do |f|     
        _html_body(f, css) do
          f.puts "<h1>#{card_title}</h1><br><hr>"
          url_ref = nil
          @data.each do |url, frameable, title|
            url_ref = (frameable == "yes") ? "href = '#{url}'" : _blank(url)
            css = "color: #8888FF; text-decoration: none; font-size: 21px"  # ; font-family: verdana"
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
                   style="text-decoration: none; color: black"> #{card_title}</a>
              </h5>
              <div class="collapse" id="#{tag}">
        EOS
        @data.each do |url2, frameable, title|
          main_ref = %[href="javascript: void(0)" onclick="javascript:open_main('#{url2}')"]
          tab_ref  = %[href="#{url2}"]
          url_ref = (frameable == "yes") ? main_ref : tab_ref
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
