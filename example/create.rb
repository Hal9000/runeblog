major, minor = RUBY_VERSION.split(".").values_at(0,1)
ver = major.to_i*10 + minor.to_i
abort "Need Ruby 2.4 or greater" unless ver >= 24

require 'date'

require 'global'
require 'runeblog'
require 'repl'

def bold(str)
  "\e[1m#{str}\e[0m"
end

def debug(str = "")
  t = Time.now
  time = t.to_f.to_s
  n = time.index(".")
  msec = time[n..(n+2)]
  time = t.strftime("%H:%M:%S") + msec
  STDERR.puts "#{'%-11s' % time}  #{str}"
end

@fake_date = Date.today - 40

def make_post(x, title, teaser, body, views=[])
  debug "      make_post #{bold(title)}"
  pubdate = @fake_date.strftime("%Y-%m-%d")
  @fake_date += (rand(3) + 1)
  x.create_new_post(title, true, teaser: teaser, body: body, views: views,
                    pubdate: pubdate)
end


#  "Main"...

t0 = Time.now

puts
debug bold("Generating test blog...")

# RuneBlog.create_new_blog_repo(".blogs")
x = RuneBlog.new(".blogs")

debug("create_view: #{bold('example')}")
x.create_view("example")   # FIXME remember view title!

#### FIXME later!!
vars = <<-VARS

.variables
blog       A Place for My Stuff
blog.desc  with apologies to george carlin
.end
VARS

File.open(".blogs/views/around_austin/themes/standard/global.lt3", "a") do |f|
  f.puts vars
end
####

debug("** generate_view: #{bold('example')}")
x.generate_view("example")

debug("-- change_view: #{bold('example')}")
x.change_view("example")    # 1 2 7 8 9 

### Posts imported here...

debug
debug "** generate_index #{bold("example")}"
x.generate_index("example") 

debug
x.change_view("example")
debug bold("...finished.\n")

t1 = Time.now

elapsed = t1 - t0
puts "Elapsed: #{'%3.2f' % elapsed} secs\n "

