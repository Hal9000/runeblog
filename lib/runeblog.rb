
class RuneBlog
  VERSION = "0.0.22"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
  DefaultData = Path + "/../data"

  BlogHeader  = File.read(DefaultData + "/blog_header.html")  rescue "not found"
  BlogTrailer = File.read(DefaultData + "/blog_trailer.html") rescue "not found"
  PostHeader  = File.read(DefaultData + "/post_header.html")  rescue "not found"
  PostTrailer = File.read(DefaultData + "/post_trailer.html") rescue "not found"
end

require 'find'
require 'yaml'
require 'rubygems'
require 'ostruct'
require 'livetext'

def clear
  puts "\e[H\e[2J"  # clear screen
end

def red(text)
  "\e[31m#{text}\e[0m"
end

def blue(text)
  "\e[34m#{text}\e[0m"
end

def bold(str)
  "\e[1m#{str}\e[22m"
end

def interpolate(str)
  wrap = "<<-EOS\n#{str}EOS"
  eval wrap
end


### ask

def ask(prompt, meth = :to_s)
  print prompt
  STDOUT.flush
  STDIN.gets.chomp.send(meth)
end

### quit

def quit
  puts
  exit
end

### version

def version
  puts "\n  " + RuneBlog::VERSION
end

### new_blog!

def new_blog!
  unless File.exist?(".blog")
    yn = ask(red("  No .blog found. Create new blog? "))
    if yn.upcase == "Y"
      #-- what if data already exists?
      system("cp -r #{RuneBlog::DefaultData} .")
      File.open(".blog", "w") do |f| 
        f.puts "data" 
        f.puts "no_default"
      end
      File.open("data/VERSION", "a") {|f| f.puts "\nBlog created: " + Time.now.to_s }
    end
  end
end

### next_sequence

def next_sequence
  @config.sequence += 1
  File.open("#{@config.root}/sequence", "w") {|f| f.puts @config.sequence }
  @config.sequence
end

### make_slug

def make_slug(title, seq=nil)
  num = '%04d' % (seq || next_sequence)   # FIXME can do better
  slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  "#{num}-#{slug}"
end

### read_config

def read_config
  cfg_file = ".blog"
  @config = OpenStruct.new
  # What views are there? Deployment, etc.
  # Crude - FIXME later
  new_blog! unless File.exist?(cfg_file)

  lines = File.readlines(cfg_file).map {|x| x.chomp }
  root = lines[0]
  @view ||= lines[1]
  dirs = Dir.entries("#{root}/views/") - %w[. ..]
  dirs.reject! {|x| ! File.directory?("#{root}/views/#{x}") }
  @config.root = root
  @config.views = dirs
  @config.sequence = File.read(root + "/sequence").to_i
end

### create_empty_post

def create_empty_post
  @template = <<-EOS
.mixin liveblog

.liveblog_version 

.title #@title
.pubdate #@date
.views #@view

Teaser goes here.
.readmore
Remainder of post goes here.
EOS

  @slug = make_slug(@title)
  @fname = @slug + ".lt3"
  File.open("#{@config.root}/src/#{@fname}", "w") {|f| f.puts @template }
  @fname
end

### edit_post

def edit_post(file)
  system("vi #{@config.root}/src/#{file}")
end

### process_post

def process_post(file)
  @main ||= Livetext.new
  @main.main.output = File.new("/tmp/WHOA","w")
  puts "  Processing: #{Dir.pwd} :: #{file}"
path = @config.root + "/src/#{file}"
  @meta = @main.process_file(path)
  @meta.slug = make_slug(@meta.title, @config.sequence)
  @meta.slug = file.sub(/.lt3$/, "")
  @meta
end

### reload_post

def reload_post(file)
  @main ||= Livetext.new
  @main.main.output = File.new("/tmp/WHOA","w")
  @meta = process_post(file)
  @meta.slug = file.sub(/.lt3$/, "")
  @meta
end

### posting

def posting(view, meta)
  ref = "#{view}/#{meta.slug}/index.html"
  <<-HTML
    <br>
    <font size=+1>#{meta.pubdate}&nbsp;&nbsp;</font>
    <font size=+2 color=blue><a href=../#{ref} style="text-decoration: none">#{meta.title}</font></a>
    <br>
    #{meta.teaser}  
    <a href=../#{ref} style="text-decoration: none">Read more...</a>
    <br><br>
    <hr>
  HTML
end

### generate_index

def generate_index(view)
  # Gather all posts, create list
  vdir = "#{@config.root}/views/#{view}"
  posts = Dir.entries(vdir).grep /^\d\d\d\d/
  posts = posts.sort.reverse

  # Add view header/trailer
  @bloghead = interpolate(BlogHeader)
  @blogtail = interpolate(BlogTrailer)

  # Output view
  posts.map! {|post| YAML.load(File.read("#{vdir}/#{post}/metadata.yaml")) }
  out = @bloghead
  posts.each {|post| out << posting(view, post) }
  out << @blogtail
  File.open("#{vdir}/index.html", "w") {|f| f.puts out }
end

### link_post_view

def link_post_view(view)
  # Create dir using slug (index.html, metadata?)
  vdir = "#{@config.root}/views/#{view}"
  dir = "#{vdir}/#{@meta.slug}"
  cmd = "mkdir -p #{dir}"    #-- FIXME what if this exists??
  puts "    Running: #{cmd}"
  system(cmd)
  File.write("#{dir}/metadata.yaml", @meta.to_yaml)
  # Add header/trailer to post index
  @posthead = interpolate(PostHeader)
  @posttail = interpolate(PostTrailer)
  File.open("#{dir}/index.html", "w") do |f|
    f.puts @posthead
    f.puts @meta.body
    f.puts @posttail
  end
  generate_index(view)
end

### link_post

def link_post(meta)
  # First gather the views
  views = meta.views
  views.each {|view| puts "Handling view '#{view}'"; link_post_view(view) }
end

### rebuild

def rebuild
  files = Dir.entries("#{@config.root}/src/").grep /\d\d\d\d.*.lt3$/
  files.map! {|f| File.basename(f) }
  files.each {|f| p f }
  files = files.sort.reverse
  files.each do |file|
    reload_post(file)
    link_post(@meta)
    publish_post
  end
end

### relink

def relink
  @config.views.each do |view|
    generate_index(view)
  end
end

### publish?

def publish?
  yn = ask(red("  Publish? y/n "))
  yn.upcase == "Y"
end

### publish_post

def publish_post
  # Grab destination data
  # scp changed files over
  puts "    Publish: Not implemented yet"
end

### list_views

def list_views
  read_config unless @config
  puts
  @config.views.each {|v| puts "  #{v}" }
end

### change_view

def change_view(arg = nil)
  if arg.nil?
    puts "\n  #@view"
  elsif @config.views.include?(arg)
    @view = arg
  else
    puts "view #{arg.inspect} does not exist"
  end
end

### new_view

def new_view(arg = nil)
  arg = nil if arg == ""
  read_config unless @config
  arg ||= ask("New view: ")  # check validity later
  raise "view #{arg} already exists" if @config.views.include?(arg)

  dir = @config.root + "/views/" + arg
  cmd = "mkdir -p #{dir}/custom"
  system(cmd)
  File.write("#{dir}/custom/blog_header.html",  RuneBlog::BlogHeader)
  File.write("#{dir}/custom/blog_trailer.html", RuneBlog::BlogTrailer)
  File.write("#{dir}/custom/post_header.html",  RuneBlog::PostHeader)
  File.write("#{dir}/custom/post_trailer.html", RuneBlog::PostTrailer)
  @config.views << arg
end

### import

def import(arg = nil)
  read_config unless @config
  arg = nil if arg == ""
  arg ||= ask("Filename: ")  # check validity later
  name = arg
  grep = `grep ^.title #{name}`
  @title = grep.sub(/^.title /, "")
  @slug = make_slug(@title)
  @fname = @slug + ".lt3"
  system("cp #{name} #{@config.root}/src/#@fname")
  edit_post(@fname)
  process_post(@fname)
  if publish?
    link_post(@meta)
    publish_post
  end
end

### new_post

def new_post
  read_config unless @config
  @title = ask("Title: ")
  @today = Time.now.strftime("%Y%m%d")
  @date = Time.now.strftime("%Y-%m-%d")

  file = create_empty_post
  edit_post(file)
# file = @config.root + "/src/" + file
  process_post(file)  #- FIXME handle each view
  if publish?
    link_post(@meta)
    publish_post
  end
end

### remove_post

#-- FIXME affects linking, building, deployment...

def remove_post(arg)
  id = Integer(arg) rescue raise("'#{arg}' is not an integer")
  tag = "#{'%04d' % id}-"
  files = Find.find("#{@config.root}").to_a
  files = files.grep(/#{tag}/)
  if files.empty?
    puts red("\n  No such post found")
    return
  end
  puts
  files.each {|f| puts "  #{f}" }
  ques = files.size > 1 ? "\n  Delete all these? " : "\n  Delete? "
  yn = ask red(ques)
  if yn.downcase == "y"   #-- maybe implement trash later?
    system("rm -rf #{files.join(' ')}")
    puts red("\n  Deleted")
  else
    puts red("\n  No action taken")
  end
rescue => err
  puts err
  puts
end

### list_posts

def list_posts
  dir = "#{@config.root}/views/#@view/"
  Dir.chdir(dir) do
    posts = Dir.entries(".").grep(/^0.*/)
    puts
    if posts.empty?
      puts "  No posts"
    else
      posts.each {|post| puts "  #{post}" }
    end
  end
rescue 
  puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
  exit
end

### list_drafts

def list_drafts
  dir = "#{@config.root}/src"
  Dir.chdir(dir) do
    posts = Dir.entries(".").grep(/^0.*.lt3/)
    puts
    if posts.empty?
      puts "  No posts"
    else
      posts.each {|post| puts "  #{post.sub(/.lt3$/, "")}" }
    end
  end
rescue 
  puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
  exit
end

