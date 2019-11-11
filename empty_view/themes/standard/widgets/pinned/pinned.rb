# Custom code for 'pinned' widget

class ::RuneBlog::Widget
  class Pinned
    Type, Title = "pinned", "Pinned posts"

    def initialize(repo)
      @blog = repo
      @datafile = "list.data"
      # f = File.new("/tmp/mehhh", "w")
      @lines = File.exist?(@datafile) ? File.readlines(@datafile) : []
      # f.puts #{@lines.inspect} in #{Dir.pwd}" 
      File.open("/tmp/mehhh", "w") {|f| f.puts "#{@lines.inspect} in #{Dir.pwd}" }
    end

    def _html_body(file, css = nil)    # FIXME
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

    def build
      posts = nil
      Dir.chdir(@blog.root/:posts) { posts = Dir["*"] }
      hash = {}
      @links = []
      @lines.each do |x| 
        num, title = x.chomp.split(" ", 2)
        hash[num] = title
        pre = '%04d' % num 
        nslug = posts.grep(/#{pre}-/).first
        name = nslug[5..-1]
        link = name+".html"
        @links << [title, link]
      end
      write_main
      write_card
    end

    def write_main
      tag = Type
      card_title = Title
      css = "* { font-family: verdana }"
      mainfile = "#{tag}-main"
      File.open("#{mainfile}.html", "w") do |f|
        _html_body(f, css) do
f.puts "<!-- #{@lines.inspect} in #{Dir.pwd} -->"
          f.puts "<h1>#{card_title}</h1><br><hr>"
          @links.each do |title, file| 
            title = title.gsub(/\\/, "")  # kludge
            css = "color: #8888FF; text-decoration: none; font-size: 21px" 
            f.puts %[<a style="#{css}" href="../../#{file}">#{title}</a> <br>]
          end
        end
      end
    end

    def write_card
      tag = Type
      url = :widgets/tag/tag+"-main.html"
      card_title = Title
      cardfile = "#{tag}-card"
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
        @links.each do |title, file|  
          url2 = file
          url_ref = %[href="javascript: void(0)" onclick="javascript:open_main('#{url2}')"]
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
