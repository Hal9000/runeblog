
# Reopening...

module RuneBlog::REPL
  Patterns = 
    {"help"              => :cmd_help, 
     "h"                 => :cmd_help,

     "version"           => :cmd_version,
     "v"                 => :cmd_version,

     "list views"        => :cmd_list_views, 
     "lsv"               => :cmd_list_views, 

     "new view $name"    => :cmd_new_view,

     "new post"          => :cmd_new_post,
     "p"                 => :cmd_new_post,
     "post"              => :cmd_new_post,

     "change view $name" => :cmd_change_view,
     "cv $name"          => :cmd_change_view,
     "cv"                => :cmd_change_view,  # 0-arity must come second

     "list posts"        => :cmd_list_posts,
     "lsp"               => :cmd_list_posts,

     "list drafts"       => :cmd_list_drafts,
     "lsd"               => :cmd_list_drafts,

     "rm $postid"        => :cmd_remove_post,

     "kill >postid"      => :cmd_kill, 

     "edit $postid"      => :cmd_edit_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,

     "preview"           => :cmd_preview,

     "pre"               => :cmd_preview,

     "browse"            => :cmd_browse,

     "relink"            => :cmd_relink,

     "rebuild"           => :cmd_rebuild,

     "deploy"            => :cmd_deploy,

     "q"                 => :cmd_quit,
     "quit"              => :cmd_quit
   }
  
  Regexes = {}
  Patterns.each_pair do |pat, meth|
    rx = "^" + pat
    rx.gsub!(/ /, " +")
    rx.gsub!(/\$(\w+) */) { " *(?<#{$1}>\\w+)" }
    # How to handle multiple optional args?
    rx.sub!(/>(\w+)$/) { "(.+)" }
p rx if rx =~ /kill/
    rx << "$"
    rx = Regexp.new(rx)
    Regexes[rx] = meth
  end

  def self.choose_method(cmd)
    found = nil
    params = []
    Regexes.each_pair do |rx, meth|
      m = cmd.match(rx)
# puts "#{rx} =~ #{cmd.inspect}  --> #{m.to_a.inspect}"
      result = m ? m.to_a : nil
      next unless result
      found = meth
      params = m[1..-1]
    end
    meth = found || :cmd_INVALID
    params = cmd if meth == :cmd_INVALID
    [meth, params]
  end
  def error(err)
    str = "\n  Error: #{red(err)}"
    puts str
    puts err.backtrace
  end

  def ask(prompt, meth = :to_s)
    print prompt
    STDOUT.flush
    STDIN.gets.chomp.send(meth)
  end

  def yesno(prompt, meth = :to_s)
    print prompt
    STDOUT.flush
    STDIN.gets.chomp.upcase[0] == "Y"
  end

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
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def colored_slug(slug)
    red(slug[0..3])+blue(slug[4..-1])
  end

  ### process_post

  def process_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
    path = @root + "/src/#{file}"
    @meta = @main.process_file(path, binding)
    raise "process_file returned nil" if @meta.nil?

    slug = @blog.make_slug(@meta.title, @blog.sequence)
    slug = file.sub(/.lt3$/, "")
    @meta.slug = slug
    @meta
  rescue => err
    error(err)
  end

  ### reload_post

  def reload_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")  # FIXME srsly?
    @meta = process_post(file)
    @meta.slug = file.sub(/.lt3$/, "")
    @meta
  rescue => err
    error(err)
  end

  ### posting

  def posting(view, meta)
    # FIXME clean up and generalize
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
    vdir = "#@root/views/#{view}"
    posts = Dir.entries(vdir).grep /^\d\d\d\d/
    posts = posts.sort.reverse

    # Add view header/trailer
    head = File.read("#{vdir}/custom/blog_header.html") rescue RuneBlog::BlogHeader
    tail = File.read("#{vdir}/custom/blog_trailer.html") rescue RuneBlog::BlogTrailer
    @bloghead = interpolate(head)
    @blogtail = interpolate(tail)

    # Output view
    posts.map! {|post| YAML.load(File.read("#{vdir}/#{post}/metadata.yaml")) }
    File.open("#{vdir}/index.html", "w") do |f|
      f.puts @bloghead
      posts.each {|post| f.puts posting(view, post) }
      f.puts @blogtail
    end
  rescue => err
    error(err)
  end

  ### create_dir

  def create_dir(dir)
    cmd = "mkdir -p #{dir} >/dev/null 2>&1"
    result = system(cmd) 
    raise "Can't create #{dir}" unless result
  end

  ### link_post_view

  def link_post_view(view)
    # Create dir using slug (index.html, metadata?)
    vdir = @blog.viewdir(view)
    dir = vdir + @meta.slug + "/"
    create_dir(dir + "assets") 
    File.write("#{dir}/metadata.yaml", @meta.to_yaml)
    template = File.read(vdir + "custom/post_template.html")
    post = interpolate(template)
    File.write(dir + "index.html", post)
    generate_index(view)
  rescue => err
    error(err)
  end

  ### find_asset

#   def find_asset(asset)    # , views)
# # STDERR.puts "repl find_asset: @meta = #{@meta.inspect}"
#     views = @meta.views
#     views.each do |view| 
#       vdir = @config.viewdir(view)
#       post_dir = "#{vdir}#{@meta.slug}/assets/"
#       path = post_dir + asset
#       STDERR.puts "          Seeking #{path}"
#       return path if File.exist?(path)
#     end
#     views.each do |view| 
#       dir = @config.viewdir(view) + "/assets/"
#       path = dir + asset
#       STDERR.puts "          Seeking #{path}"
#       return path if File.exist?(path)
#     end
#     top = @root + "/assets/"
#     path = top + asset
#     STDERR.puts "          Seeking #{path}"
#     return path if File.exist?(path)
# 
#     return nil
#   end
# 
#   ### find_all_assets
# 
#   def find_all_assets(list, views)
# #   STDERR.puts "\n  Called find_all_assets with #{list.inspect}"
#     list ||= []
#     list.each {|asset| puts "#{asset} => #{find_asset(asset, views)}" }
#   end

  ### publish_post

  def publish_post(meta)
    puts "  #{colored_slug(meta.slug)}"
    # First gather the views
    views = meta.views
    print "       Views: "
    views.each do |view| 
      print "#{view} "
      link_post_view(view)
    end
#   assets = find_all_assets(@meta.assets, views)
    puts
  rescue => err
    error(err)
  end

  ### rebuild_post
  
  def rebuild_post(file)
    reload_post(file)
    publish_post(@meta)       # FIXME ??
  rescue => err
    error(err)
  end

  def import(arg = nil)
    open_blog unless @blog

    arg = nil if arg == ""
    arg ||= ask("Filename: ")  # check validity later
    name = arg
    grep = `grep ^.title #{name}`
    @title = grep.sub(/^.title /, "")
    @slug = @blog.make_slug(@title)
    @fname = @slug + ".lt3"
    result = system("cp #{name} #@root/src/#@fname")
    raise "Could not copy #{name} to #@root/src/#@fname" unless result

    edit_initial_post(@fname)
    process_post(@fname)
    publish_post(@meta) # if publish?
  rescue => err
    error(err)
  end

end
