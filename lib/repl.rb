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
        system("cp -r #{RuneBlog::DefaultData} .")
        File.open(".blog", "w") do |f| 
          f.puts "data" 
          f.puts "no_default"
        end
        File.open("data/VERSION", "a") {|f| f.puts "\nBlog created: " + Time.now.to_s }
      end
    end
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
    @config = RuneBlog::Config.new(".blog")

    @view = @config.view           # current view
    @sequence = @config.sequence
    @root = @config.root
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
    File.open("#@root/src/#@fname", "w") {|f| f.puts @template }
    @fname
  end

  ### edit_initial_post

  def edit_initial_post(file)
    system("vi #@root/src/#{file} +8 ")
  end

  ### open_remote

  def open_remote
    @deploy ||= {}
    unless @deploy[@view]
      puts red("\n  Deploy first.")
      return
    end
    lines = @deploy[@view]
    user, server, sroot, spath = *lines
    system("open 'http://#{server}/#{spath}'")
  end

  ### open_local

  def open_local
    system("open #{@config.viewdir(@view)}/index.html")
  end

  def deploy
    # TBD clunky FIXME 
    @deploy ||= {}
    deployment = @config.viewdir(@view) + "deploy"
    lines = File.readlines(deployment).map {|x| x.chomp }
    @deploy[@view] = lines
    user, server, sroot, spath = *lines
    vdir = @config.viewdir(@view)
    files = ["#{vdir}/index.html"]
    files += Dir.entries(vdir).grep(/^\d\d\d\d/).map {|x| "#{vdir}/#{x}" }
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_deployed") }
    puts "\n  Files:"
    files.each {|f| puts "    " + f }
    puts
    dir = "#{sroot}/#{spath}"
    cmd = "scp -r #{files.join(' ')} root@#{server}:#{dir} >/dev/null 2>&1"
    print red("\n  Deploying #{files.size} files... ")
  # puts cmd
    system(cmd)
    File.write("#{vdir}/last_deployed", files)
    puts red("finished.")
  end

  ### process_post

  def process_post(file)
    @main ||= Livetext.new
    @main.main.output = File.new("/tmp/WHOA","w")
  # puts "  Processing: #{Dir.pwd} :: #{file}"
    path = @root + "/src/#{file}"
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
  end

  ### link_post_view

  def link_post_view(view)
    # Create dir using slug (index.html, metadata?)
    vdir = @config.viewdir(view)
    dir = vdir + @meta.slug + "/"
    cmd = "mkdir -p #{dir}"    #-- FIXME what if this exists??
    system(cmd)
    File.write("#{dir}/metadata.yaml", @meta.to_yaml)
    template = File.read(vdir + "custom/post_template.html")
    post = interpolate(template)
    File.write(dir + "index.html", post)
    generate_index(view)
  end

  ### link_post

  def link_post(meta)
    puts "  #{colored_slug(meta.slug)}"
    # First gather the views
    views = meta.views
    print "       Views: "
    views.each do |view| 
      print "#{view} "
      link_post_view(view)
    end
    puts
  end

  ### rebuild_post
  
  def rebuild_post(file)
    reload_post(file)
    link_post(@meta)       # FIXME ??
    publish_post
  end

  ### rebuild

  def rebuild
    puts
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files.each {|file| rebuild_post(file) }
  end

  ### relink

  def relink
    @config.views.each {|view| generate_index(view) }
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
  # puts "    Publish: Not implemented yet"
  end

  ### list_views

  def list_views
    abort "Config file not read"  unless @config
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

    dir = @root + "/views/" + arg + "/"
    cmd = "mkdir -p #{dir + 'custom'}"
    system(cmd)
    File.write(dir + "custom/blog_header.html",  RuneBlog::BlogHeader)
    File.write(dir + "custom/blog_trailer.html", RuneBlog::BlogTrailer)
    File.write(dir + "last_deployed", "Initial creation")
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
    system("cp #{name} #@root/src/#@fname")
    edit_initial_post(@fname)
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
    edit_initial_post(file)
  # file = @root + "/src/" + file
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
    files = Find.find(@root).to_a
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

  ### edit_post

  #-- FIXME affects linking, building, deployment...

  def edit_post(arg)
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}-"
    files = Find.find(@root+"/src").to_a
    files = files.grep(/#{tag}/)
    files = files.map {|f| File.basename(f) }
    if files.size > 1
      puts red("Multiple files: #{files}") 
      return
    end
    if files.empty?
      puts red("\n  No such post found")
      return
    end

    file = files.first
    system("vi #@root/src/#{file}")
    rebuild_post(file)
  rescue => err
    puts err
    puts
  end

  ### list_posts

  def list_posts
    dir = @config.viewdir(@view)
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*/)
      puts
      if posts.empty?
        puts "  No posts"
      else
        posts.each {|post| puts "  #{colored_slug(post)}" }
      end
    end
  rescue 
    puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
    exit
  end

  ### list_drafts

  def list_drafts
    dir = "#@root/src"
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*.lt3/)
      puts
      if posts.empty?
        puts "  No posts"
      else
        posts.each {|post| puts "  #{colored_slug(post.sub(/.lt3$/, ""))}" }
      end
    end
  rescue 
    puts "Oops? cwd = #{Dir.pwd}   dir = #{dir}"
    exit
  end

end
