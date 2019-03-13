$LOAD_PATH << "./li"

major, minor = RUBY_VERSION.split(".").values_at(0,1)
ver = major.to_i*10 + minor.to_i
abort "Need Ruby 2.4 or greater" unless ver >= 24

require 'global'
# require 'rubytext'
require 'repl'

def getch
# sleep 5
end

def debug(str)
# STDERR.puts str
end

def make_post(x, title)
  meta = OpenStruct.new
  num = x.create_new_post(title, true)
  num
end

def show_lines(text)
  lines = text.split("\n")
  str = "#{lines.size} lines\n"
  lines.each {|line| str << "  #{line.inspect}\n" }
  str
end


system("rm -rf .blog")
RuneBlog.create_new_blog(".blog/data_test")
x = RuneBlog.new
x.create_view("alpha_view")

# Hack:
system("cp publish .blog/data_test/views/alpha_view/publish")
system("cp fakeimage.jpg .blog/data_test/assets/")
system("cp fakeimage.jpg .blog/data_test/views/alpha_view/assets/")

x.create_view("beta_view")
x.create_view("gamma_view")

x.change_view("alpha_view")    # 1 2 7 8 9 
make_post(x, "Post number 1")
make_post(x, "Post number 2")
x.change_view("beta_view")     # 3 5 6
make_post(x, "Post number 3")
x.change_view("gamma_view")    # 4 10
make_post(x, "Post number 4")
x.change_view("beta_view")
make_post(x, "Post number 5")
make_post(x, "Post number 6")
x.change_view("alpha_view")
make_post(x, "Post number 7")
make_post(x, "Post number 8")
make_post(x, "Post number 9")
x.change_view("gamma_view")
make_post(x, "Post number 10")
x.change_view("alpha_view")
