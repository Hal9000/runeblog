# Custom code for 'pages' widget

# How to update repl code?

class ::RuneBlog::Widget
  class Pages
    def self.build
      # build child pages
      children = Dir["*.lt3"] - ["pages.lt3"]
      children.each do |child|
        dest = child.sub(/.lt3$/, ".html")
        xlate src: child, dst: dest  # , debug: true
      end
      # build mainfile
      # build cardfile
    end

    def self.edit_menu
    end

    def self.refresh
    end
  end
end
