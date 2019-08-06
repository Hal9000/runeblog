$LOAD_PATH << "./lib"

major, minor = RUBY_VERSION.split(".").values_at(0,1)
ver = major.to_i*10 + minor.to_i
abort "Need Ruby 2.4 or greater" unless ver >= 24

Home = Dir.pwd

require 'global'
require 'runeblog'
require 'repl'

def getch
# sleep 5
end

def debug(str)
# STDERR.puts str
end

def make_post(x, title, teaser, body, views=[])
STDERR.puts "\n========= make_post '#{title}'"
  meta = OpenStruct.new
  num = x.create_new_post(title, true, teaser: teaser, body: body, other_views: views)
  num
end

def show_lines(text)
  lines = text.split("\n")
  str = "#{lines.size} lines\n"
  lines.each {|line| str << "  #{line.inspect}\n" }
  str
end

system("rm -rf .blogs")
RuneBlog.create_new_blog_repo('test_view', ".blogs/data")
x = RuneBlog.new

x.create_view("around_austin")   # FIXME remember view title!

# Hack:
if File.exist?("publish")
  system("cp publish .blogs/data/views/around_austin/publish")
end

x.create_view("computing")

x.create_view("music")

x.change_view("around_austin")    # 1 2 7 8 9 

make_post(x, "What's at Stubbs...", <<-EXCERPT, <<-BODY, ["music"])
Stubbs has been around for longer than civilization.
EXCERPT
That's a good thing. But their music isn't always the greatest.
BODY

make_post(x, "The new amphitheatre is overrated", <<-EXCERPT, <<-BODY)
It used to be that all major concerts played the Erwin Center.
EXCERPT
Now, depending on what you consider "major," blah blah blah...
BODY

# x.change_view("computing")     # 3 5 6
# 
# make_post(x, "Elixir Conf coming up...", <<-EXCERPT, <<-BODY)
# The next Elixir Conf is always coming up. 
# EXCERPT
# I mean, unless the previous one was the last one ever, which I don't expect to 
# happen for a couple of decades.
# BODY
# 
# x.change_view("music")    # 4 10
# 
# make_post(x, "Does indie still matter?", <<-EXCERPT, <<-BODY)
# Indie msic blah blah blah blah....
# EXCERPT
# And more about indie music.
# BODY
# 
# x.change_view("computing")
# 
# make_post(x, "The genius of Scenic", <<-EXCERPT, <<-BODY)
# Boyd Multerer is a genius.
# EXCERPT
# And so is Scenic.
# BODY
# 
# make_post(x, "The future of coding", <<-EXCERPT, <<-BODY)
# Someday you can forget your text editor entirely.
# EXCERPT
# But that day hasn't come yet.
# BODY

x.change_view("around_austin")

make_post(x, "The graffiti wall", <<-EXCERPT, <<-BODY)
RIP, Hope Gallery
EXCERPT
It's been a while since I was there. They say it was torn down
while I wasn't looking.
BODY

make_post(x, "The Waller Creek project", <<-EXCERPT, <<-BODY)
Will it ever be finished?
EXCERPT
Blah blah Waller Creek blah blah...
BODY

make_post(x, "Life on Sabine Street", <<-EXCERPT, <<-BODY)
It's like Pooh Corner, except not.
EXCERPT
This is about Sabine St, blah blah lorem ipsum dolor...
BODY

x.change_view("music")

make_post(x, "Remember Modest Mouse?", <<-EXCERPT, <<-BODY, ["around_austin"])
They date to the 90s or before. 
EXCERPT
But I first heard of them
in 2005.
BODY

x.change_view("around_austin")

