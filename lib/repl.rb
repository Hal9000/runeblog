require 'runeblog'

module RuneBlog::REPL

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
        result = system("cp -r #{RuneBlog::DefaultData} .")
        raise "Error copying default data" unless result

        File.open(".blog", "w") do |f| 
          f.puts "data" 
          f.puts "no_default"
        end
        File.open("data/VERSION", "a") {|f| f.puts "\nBlog created: " + Time.now.to_s }
      end
    end
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end 

  ### make_slug

  def make_slug(title, seq=nil)
    num = '%04d' % (seq || @config.next_sequence)   # FIXME can do better
    slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    "#{num}-#{slug}"
  end

  ### read_config

  def read_config
    # Crude - FIXME later
    cfg_file = ".blog"
    new_blog! unless File.exist?(cfg_file)
    @config = RuneBlog::Config.new(cfg_file)

    @view = @config.view           # current view
    @sequence = @config.sequence
    @root = @config.root
    @config
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### create_empty_post

  def create_empty_post
    @template = <<-EOS
.mixin liveblog

.title #@title
.pubdate #@date
.views #@view

.teaser
Teaser goes here.
.end
Remainder of post goes here.
  EOS

    @slug = make_slug(@title)
    @fname = @slug + ".lt3"
    File.open("#@root/src/#@fname", "w") {|f| f.puts @template }
    @fname
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### edit_initial_post

  def edit_initial_post(file)
    result = system("vi #@root/src/#{file} +8 ")
    raise "Problem editing #@root/src/#{file}" unless result
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### open_remote

  def open_remote
    @deploy ||= {}
    return puts red("\n  Deploy first.") unless @deploy[@view]

    lines = @deploy[@view]
    user, server, sroot, spath = *lines
    result = system("open 'http://#{server}/#{spath}'")
    raise "Problem opening http://#{server}/#{spath}" unless result
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### open_local

  def open_local
    result = system("open #{@config.viewdir(@view)}/index.html")
    raise "Problem opening #{@config.viewdir(@view)}/index.html" unless result
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  def deploy
    # TBD clunky FIXME 
    @deploy ||= {}
    deployment = @config.viewdir(@view) + "deploy"
    raise "File '#{deployment}' not found" unless File.exist?(deployment)

    lines = File.readlines(deployment).map {|x| x.chomp }
    @deploy[@view] = lines
    user, server, sroot, spath = *lines
    vdir = @config.viewdir(@view)
    files = ["#{vdir}/index.html"]
    files += Dir.entries(vdir).grep(/^\d\d\d\d/).map {|x| "#{vdir}/#{x}" }
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_deployed") }
    return puts red("\n  No files to deploy") if files.empty?

    puts "\n  Files:"
    files.each {|f| puts "    " + f }
    puts
    dir = "#{sroot}/#{spath}"
    # FIXME - may or may not already exist
    result = system("ssh root@#{server} mkdir #{dir}") 

    cmd = "scp -r #{files.join(' ')} root@#{server}:#{dir} >/dev/null 2>&1"
    print red("\n  Deploying #{files.size} files... ")
    result = system(cmd)
    raise "Problem occurred in deployment" unless result

    File.write("#{vdir}/last_deployed", files)
    puts red("finished.")
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### process_post

  def process_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
    path = @root + "/src/#{file}"
    @meta = @main.process_file(path, binding)
    raise "process_file returned nil" if @meta.nil?

    @meta.slug = make_slug(@meta.title, @config.sequence)
    @meta.slug = file.sub(/.lt3$/, "")
    @meta
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
    puts
  end

  ### reload_post

  def reload_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
    @meta = process_post(file)
    @meta.slug = file.sub(/.lt3$/, "")
    @meta
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
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
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
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
    vdir = @config.viewdir(view)
    dir = vdir + @meta.slug + "/"
    create_dir(dir + "assets") 
    File.write("#{dir}/metadata.yaml", @meta.to_yaml)
    template = File.read(vdir + "custom/post_template.html")
    post = interpolate(template)
    File.write(dir + "index.html", post)
    generate_index(view)
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### find_asset

  def find_asset(asset)    # , views)
# STDERR.puts "repl find_asset: @meta = #{@meta.inspect}"
    views = @meta.views
    views.each do |view| 
      vdir = @config.viewdir(view)
      post_dir = "#{vdir}#{@meta.slug}/assets/"
      path = post_dir + asset
      STDERR.puts "  Seeking #{path}"
      return path if File.exist?(path)
    end
    views.each do |view| 
      dir = @config.viewdir(view) + "/assets/"
      path = dir + asset
      STDERR.puts "  Seeking #{path}"
      return path if File.exist?(path)
    end
    top = @root + "/assets/"
    path = top + asset
    STDERR.puts "  Seeking #{path}"
    return path if File.exist?(path)

    return nil
  end

  ### find_all_assets

  def find_all_assets(list, views)
#   STDERR.puts "\n  Called find_all_assets with #{list.inspect}"
    list ||= []
    list.each {|asset| puts "#{asset} => #{find_asset(asset, views)}" }
  end

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
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### rebuild_post
  
  def rebuild_post(file)
    reload_post(file)
    publish_post(@meta)       # FIXME ??
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### rebuild

  def rebuild
    puts
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files.each {|file| rebuild_post(file) }
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### relink

  def relink
    @config.views.each {|view| generate_index(view) }
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

#  ### publish?
#
#  def publish?
#    yn = ask(red("  Publish? y/n "))
#    yn.upcase == "Y"
#  end

  ### list_views

  def list_views
    abort "Config file not read"  unless @config
    puts
    @config.views.each {|v| puts "  #{v}" }
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### change_view

  def change_view(arg = nil)
    if arg.nil?
      puts "\n  #@view"
    else
      list = @config.views.grep /^#{arg}/
      if list.size == 1
        @view = @config.view = list.first
        puts red("\n  View: #{@view}") if arg != @view
      else
        puts "view #{arg.inspect} does not exist"
      end
    end
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### new_view

  def new_view(arg = nil)
    arg = nil if arg == ""
    read_config unless @config
    arg ||= ask("New view: ")  # check validity later
    raise "view #{arg} already exists" if @config.views.include?(arg)

    dir = @root + "/views/" + arg + "/"
    create_dir(dir + 'custom')
    create_dir(dir + 'assets')

    File.write(dir + "custom/blog_header.html",  RuneBlog::BlogHeader)
    File.write(dir + "custom/blog_trailer.html", RuneBlog::BlogTrailer)
    File.write(dir + "last_deployed", "Initial creation")
    @config.views << arg
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
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
    result = system("cp #{name} #@root/src/#@fname")
    raise "Could not copy #{name} to #@root/src/#@fname" unless result

    edit_initial_post(@fname)
    process_post(@fname)
    publish_post(@meta) # if publish?
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### new_post

  def new_post
    read_config unless @config
    @title = ask("Title: ")
    @today = Time.now.strftime("%Y%m%d")
    @date = Time.now.strftime("%Y-%m-%d")

    file = create_empty_post
    edit_initial_post(file)
  # file = @root + "/src/" + file
    process_post(file)  #- FIXME handle each view
    publish_post(@meta) # if publish?
  rescue => err
    puts red("\n  Error: (line #{__LINE__} of #{File.basename(__FILE__)})  ") + err.to_s
    puts err.backtrace
  end

  ### remove_multiple_posts
  
  def remove_multiple_posts(str)
    args = str.split
    args.each {|arg| remove_post(arg, false) }
  end

  ### remove_post

  #-- FIXME affects linking, building, deployment...

  def remove_post(arg, safe=true)
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}-"
    files = Find.find(@root).to_a
    files = files.grep(/#{tag}/)
    return puts red("\n  No such post found (#{tag})") if files.empty?

    if safe
      puts
      files.each {|f| puts "  #{f}" }
      ques = files.size > 1 ? "\n  Delete all these? " : "\n  Delete? "
      yn = ask red(ques)
      if yn.downcase == "y"
        result = system("rm -rf #{files.join(' ')}")
        raise "Problem deleting file(s)" unless result
        puts red("\n  Deleted")
      else
        puts red("\n  No action taken")
      end
    else
      result = system("rm -rf #{files.join(' ')}")
      puts red("\n  Deleted:")
      files.each {|f| puts "    #{f}" }
      raise "Problem mass-deleting file(s)" unless result
    end
  rescue => err
    puts err
    puts err.backtrace
    puts
  end

  ### edit_post

  #-- FIXME affects linking, building, deployment...

  def edit_post(arg)
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}-"
    files = Find.find(@root+"/src").to_a
    files = files.grep(/#{tag}/)
    files = files.map {|f| File.basename(f) }
    return puts red("Multiple files: #{files}") if files.size > 1
    return puts red("\n  No such post found (#{tag})") if files.empty?

    file = files.first
    result = system("vi #@root/src/#{file}")
    raise "Problem editing #{file}" unless result

    rebuild_post(file)
  rescue => err
    puts err
    puts err.backtrace
    puts
  end

  ### list_posts

  def list_posts
    dir = @config.viewdir(@view)
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*/)
      if posts.empty?
        puts "\n  " + @view + ":" + red("  No posts")
      else
        puts "\n  " + @view + ":\n "
        posts.each {|post| puts "  #{colored_slug(post)}" }
      end
    end
  rescue 
    puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
    puts err.backtrace
    exit
  end

  ### list_drafts

  def list_drafts
    dir = "#@root/src"
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*.lt3/)
      puts
      if posts.empty?
        puts red("  No posts")
      else
        posts.each {|post| puts "  #{colored_slug(post.sub(/.lt3$/, ""))}" }
      end
    end
  rescue 
    puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
    puts err.backtrace
    exit
  end

end
