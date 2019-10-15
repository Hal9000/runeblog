$LOAD_PATH << "./lib"

major, minor = RUBY_VERSION.split(".").values_at(0,1)
ver = major.to_i*10 + minor.to_i
abort "Need Ruby 2.4 or greater" unless ver >= 24

Home = Dir.pwd

require 'global'
require 'runeblog'
require 'repl'

def bold(str)
  "\e[1m#{str}\e[0m"
end

def getch
# sleep 5
end

def debug(str = "")
  t = Time.now
  time = t.to_f.to_s
  n = time.index(".")
  msec = time[n..(n+2)]
  time = t.strftime("%H:%M:%S") + msec
  STDERR.puts "#{'%-11s' % time}  #{str}"
end

def make_post(x, title, teaser, body, views=[])
  debug "      make_post #{bold(title)}"
  x.create_new_post(title, true, teaser: teaser, body: body, views: views)
  views.each do |view| 
    debug
    debug "** generate_index #{bold(view)}"
    x.generate_index(view) 
  end  # recent.html
end

def show_lines(text)
  lines = text.split("\n")
  str = "#{lines.size} lines\n"
  lines.each {|line| str << "  #{line.inspect}\n" }
  str
end

#  "Main"...

t0 = Time.now

puts bold("\nGenerating test blog...")

system("rm -rf .blogs")
RuneBlog.create_new_blog_repo(".blogs")
x = RuneBlog.new(".blogs")

debug("create_view: #{bold('around_austin')}")
x.create_view("around_austin")   # FIXME remember view title!

#### FIXME later!!
vars = <<-VARS

.variables
blog       Around Austin
blog.desc  The view from downtown...
.end
VARS
File.open(".blogs/views/around_austin/themes/standard/global.lt3", "a") do |f|
  f.puts vars
end
####

debug("create_view: #{bold('computing')}")
x.create_view("computing")

debug("create_view: #{bold('music')}")
x.create_view("music")

debug("-- change_view: #{bold('around_austin')}")
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

debug("-- change_view: #{bold('computing')}")
x.change_view("computing")     # 3 5 6

make_post(x, "Elixir Conf coming up...", <<-EXCERPT, <<-BODY)
The next Elixir Conf is always coming up. 
EXCERPT
I mean, unless the previous one was the last one ever, which I don't expect to 
happen for a couple of decades.
BODY

debug("-- change_view: #{bold('music')}")
x.change_view("music")    # 4 10

make_post(x, "Does indie still matter?", <<-EXCERPT, <<-BODY)
Indie msic blah blah blah blah....
EXCERPT
And more about indie music.
BODY

debug("-- change_view: #{bold('computing')}")
x.change_view("computing")

make_post(x, "The genius of Scenic", <<-EXCERPT, <<-BODY)
Boyd Multerer is a genius.
EXCERPT
And so is Scenic.
BODY

make_post(x, "The future of coding", <<-EXCERPT, <<-BODY)
Someday you can forget your text editor entirely.
EXCERPT
But that day hasn't come yet.
BODY

debug("-- change_view: #{bold('around_austin')}")
x.change_view("around_austin")

make_post(x, "The graffiti wall", <<-EXCERPT, <<-BODY)
RIP, Hope Gallery
EXCERPT
.dropcap

It's been a while since I was there. They say it was torn down
while I wasn't looking.

This fake entry is a long one so as to demonstrate both drop-caps
(above) and an inset quote. Blah blah blah. Lorem ipsum dolor and
a partridge in a pear tree.

Wherever you go, there you are. Last night I saw upon the stair
a little man who was not there. He wasn't there again today; I
wish, I wish he'd go away.

As far as we know, our computer has never had an undetected error.
And never let it be denied that pobbles are happier without their
toes. And may your snark never be a boojum.

Contact light. Houston, this is Tranquility Base. The Eagle has
landed. That's one small step for (a) man, one giant leap for 
mankind.
.inset left 20
On a clean disk, you can seek forever.
.end

Pity this busy monster, manunkind, not. Pity rather... Listen:
There's a hell of a universe next door; let's go.
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

debug("-- change_view: #{bold('music')}")
x.change_view("music")

make_post(x, "Remember Modest Mouse?", <<-EXCERPT, <<-BODY, ["around_austin"])
They date to the 90s or before. 
EXCERPT
But I first heard of them
in 2005.
BODY

debug
debug("** generate_view: #{bold('around_austin')}")
x.generate_view("around_austin")
x.change_view("around_austin")
debug

puts bold("...finished.\n")

t1 = Time.now

elapsed = t1 - t0
puts "\nElapsed: #{'%3.2f' % elapsed} secs\n "

