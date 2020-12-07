require 'rubytext'

RubyText.start
  
#  Idea: A special sub-environment for creating a post
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

def ask(prompt)  # elsewhere?
  print prompt
  str = gets
  str.chomp! if str
  str
end

def enter_title
  puts __method__
  str = ask("Title:    ")
  puts str.inspect
end

def edit_teaser
  puts __method__
  str = ask("Teaser:   ")
  puts str.inspect
end

def add_views
  puts __method__
end

def add_tags
  puts __method__
end

def import_assets
  puts __method__
end

def save_post
  puts __method__
end

def quit_post
  puts __method__
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

enter_title
edit_teaser
add_views
add_tags
import_assets
save_post
quit_post

# getch

# curr = 0
# loop do
#   str, curr = menu(c: 10, items: items, curr: curr, sticky: true)
#   break if curr.nil?
#   puts "str = #{str}  curr = #{curr}"
# end
