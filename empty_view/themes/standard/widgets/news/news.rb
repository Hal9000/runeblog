# Custom code for 'news' widget

class ::RuneBlog::Widget
  class News
    Type, Title = "news", "News"

    def initialize(repo)
      @blog = repo
      @datafile = "list.data"
      lines = _get_data(@datafile)
      @data = lines.map {|line| line.chomp.split(/, */) }
    end

    def build
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
      mainfile = "#{Type}-main"
      css = "body { font-family: verdana }"
      File.open("#{mainfile}.html", "w") do |f|
        _html_body(f, css) do
          f.puts "<h1>#{Title}</h1><br><hr>"
          @data.each do |file, frameable, title| 
            title = title.gsub(/\\/, "")  # kludge
            case frameable
              when "yes"; url_ref = "href = '#{file}'"
              when "no";  url_ref = %[href='#{file}' target='blank']
            end
            css = "color: #8888FF; text-decoration: none; font-size: 21px"
            f.puts %[<a style="#{css}" #{url_ref}>#{title}</a> <br>]
          end
        end
      end
    end

    def write_card
      cardfile = "#{Type}-card"
      url = "widgets/#{Type}/#{Type}-main.html"
      File.open("#{cardfile}.html", "w") do |f|
        f.puts <<-EOS
          <div class="card mb-3">
            <div class="card-body">
              <h5 class="card-title">
                <button type="button" class="btn btn-primary" data-toggle="collapse" data-target="##{Type}">+</button>
                <a href="javascript: void(0)" 
                   onclick="javascript:open_main('#{url}')" 
                   style="text-decoration: none; color: black"> #{Title}</a>
              </h5>
              <div class="collapse" id="#{Type}">
        EOS
        @data.each do |file, frameable, title| 
          case frameable
            when "yes"; url_ref = _main(file)   # remote, frameable
            when "no";  url_ref = _blank(file)  # remote, not frameable
          end
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
