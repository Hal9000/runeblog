require 'rubytext'

RubyText.start
  
#  IdeaL A special sub-environment for creating a post
#  
#  1. Display: view, post number, date
#  2. Menu?
#  3.   - Edit/enter title
#  4.   - Edit teaser
#  5.   - Add views
#  6.   - Add tags
#  7.   - Import assets
#  8.   - Save 
#  9.  - Quit
# Edit body after save/quit

def enter_title
  STDSCR.puts __method__
  r = STDSCR.rows / 2 - 3
  @win = RubyText.window(1, 30, r: r, c: 30, border: false, bg: White, fg: Black)
  @win.home
  str = @win.gets
  STDSCR.puts str.inspect
  [__method__, 0]
end

def edit_teaser
  STDSCR.puts __method__
  [__method__, 1]
end

def add_views
  STDSCR.puts __method__
  [__method__, 2]
end

def add_tags
  STDSCR.puts __method__
  [__method__, 3]
end

def import_assets
  STDSCR.puts __method__
  [__method__, 4]
end

def save_post
  STDSCR.puts __method__
  [__method__, 5]
end

def quit_post
  STDSCR.puts __method__
  [__method__, 6]
end

items = {
  "Enter title"   => proc { enter_title },
  "Edit teaser"   => proc { edit_teaser },
  "Add views"     => proc { add_views },
  "Add tags"      => proc { add_tags },
  "Import assets" => proc { import_assets },
  "Save"          => proc { save_post },
  "Quit"          => proc { quit_post }
}

curr = 0
loop do
  str, curr = STDSCR.menu(c: 10, items: items, curr: curr, sticky: true)
  break if curr.nil?
  STDSCR.puts "str = #{str}  curr = #{curr}"
end
