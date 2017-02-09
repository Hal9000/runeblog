=begin

Post
----
Create a blog post
Process it
Link it
Upload to server


data
  views
    computing
      compiled
      custom
      deployment

=end

require 'rubygems'

require 'ostruct'

require 'livetext'


### ask

def ask(prompt, meth = :to_s)
  print prompt
  STDOUT.flush
  STDIN.gets.chomp.send(meth)
end

### new_blog!

def new_blog!
  unless File.exist?(".blog")
    yn = ask("No .blog found. Create new blog?")
    if yn.upcase == "Y"
      system("mkdir data")
      File.open(".blog", "w") {|f| f.puts data }
      File.open("data/sequence", "w") {|f| f.puts 0 }
    end
  end
end

### next_sequence

def next_sequence
  @config.sequence += 1
  File.open("data/sequence", "w") {|f| f.puts @config.sequence }
  @config.sequence
end

### make_slug

def make_slug
  num = '%04d' % next_sequence
  slug = @title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  "#{num}-#{slug}"
end

### read_config

def read_config
  @config = OpenStruct.new
  # What views are there? Deployment, etc.
  # Crude - FIXME later
  root = File.readlines(".blog").first.chomp rescue "myblog"
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

.title #{@title}
.pubdate #{@date}
.categories elixir ruby
.views computing

Teaser goes here.
.readmore
Remainder of post goes here.
EOS

  @slug = make_slug
  @fname = @slug + ".ltx"
  File.open("#{@config.root}/src/#{@fname}", "w") {|f| f.puts @template }
end

### edit_post

def edit_post
  system("vi #{@config.root}/src/#{@fname}")
end

### process_post

def process_post
  puts "Processing: #{@config.root}/src/#{@fname}"
  @meta = Livetext.handle_file("#{@config.root}/src/#{@fname}")   # returns metadata
end

### link_post_view

def link_post_view(view)
  # Create dir using slug (index.html, metadata?)
  dir = "#{@config.root}/views/#{view}/#@slug"
  cmd = "mkdir -p #{dir}"
  puts "Running: #{cmd}"
  system(cmd)
  File.write("#{dir}/metadata.yaml", @meta.to_yaml)
  File.write("#{dir}/index.html", @meta.body)
  # Add header/trailer to post index
  # Gather all posts
  # Create list
  # Add view header/trailer
  # Output view
end

### link_post

def link_post
  # First gather the views
  views = @meta.views
  views.each {|view| link_post_view(view) }
end

### publish?

def publish?
  yn = ask("Publish? y/n ")
  yn.upcase == "Y"
end

### publish_post

def publish_post
  # Grab destination data
  # scp changed files over
end

### list_views

def list_views
  read_config unless @config
  puts @config.views
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
  @config.views << arg
end

### import

def import(arg = nil)
  arg = nil if arg == ""
  arg ||= ask("Filename: ")  # check validity later
  name = arg
  grep = `grep ^.title #{name}`
  @title = grep.sub(/^.title /, "")
  @slug = make_slug
  @fname = @slug + ".ltx"
  system("cp #{name} #{@config.root}/src/#@fname")
  edit_post
  process_post
  if publish?
    link_post
    publish_post
  end
end

### new_post

def new_post
  read_config unless @config
  @title = ask("Title: ")
  @today = Time.now.strftime("%Y%m%d")
  @date = Time.now.strftime("%Y-%m-%d")

  create_empty_post
  edit_post
  process_post
  if publish?
    link_post
    publish_post
  end
end

