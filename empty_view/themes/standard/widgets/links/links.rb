# Custom code for 'links' widget

require 'liveblog'

class ::RuneBlog::Widget
  class Links
    Type = "links"

    def initialize(repo)
      @blog = repo
    end

    def build
      input = "list.data"
      lines = File.readlines(input)
      data = lines.map! {|x| x.chomp.split(/, */, 3) }
      css = "* { font-family: verdana }"
      card_title = "External Links"  # FIXME
      File.open("#{Type}-main.html", "w") do |f|     
        _html_body(f, css) do
          f.puts "<h1>#{card_title}</h1><br><hr>"
          url_ref = nil
          data.each do |url, frameable, title|
            url_ref = (frameable == "yes") ? "href = '#{url}'" : _blank(url)
            css = "color: #8888FF; text-decoration: none; font-size: 21px"  # ; font-family: verdana"
            f.puts %[<a style="#{css}" #{url_ref}>#{title}</a> <br>]
          end
        end
      end
      # remember -card also
    end

    def edit_menu
    end

    def refresh
    end
  end
end
