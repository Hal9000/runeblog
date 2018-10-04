$LOAD_PATH << "."

require 'lib/repl'

def make_post(x, title)
  meta = OpenStruct.new
  meta.title = title
  num = x.create_new_post(meta, true)
end

def show_lines(text)
  lines = text.split("\n")
  str = "#{lines.size} lines\n"
  lines.each {|line| str << "  #{line.inspect}\n" }
  str
end

system("rm -rf data_test")
RuneBlog.create_new_blog(Dir.pwd + "/data_test")
x = RuneBlog.new
x.create_view("alpha_view")
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
