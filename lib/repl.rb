require 'runeblog'

require 'ostruct'

=begin
  Instance vars in original code:
    @bloghead
    @blogtail
    @config
    @date
    @deploy
    @fname
    @main
    @meta
    @root
    @sequence
    @slug
    @template
    @title
    @today
    @view
=end

require 'prettiness'  # FIXME structure

module RuneBlog::REPL

  ### error

  def error(err)
    str = "\n  Error: #{red(err)}"
    puts str
    puts err.backtrace
  end

  ### ask

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

  ### quit

  def cmd_quit(arg)
    raise "Glitch: Got an argument" if arg != []
    puts "\n "
    exit
  end

  ### version

  def cmd_version(arg)
    raise "Glitch: Got an argument" if arg != []
    puts "\n  " + RuneBlog::VERSION
  end

  ### new_blog!

  def new_blog!(arg)
    raise "Glitch: Got an argument" if arg != []
    return if RuneBlog.exist?
    yn = yesno(red("  No .blog found. Create new blog? "))
    RuneBlog.create_new_blog if yn
  rescue => err
    error(err)
  end 

  ### open_blog

  def open_blog # Crude - FIXME later
#   new_blog!([]) unless RuneBlog.exist?
    @blog = RuneBlog.new
    @view = @blog.view     # current view
    @sequence = @blog.sequence
    @root = @blog.root
    @blog
  rescue => err
    error(err)
  end

  ### edit_initial_post

  def edit_initial_post(file)
    result = system("vi #@root/src/#{file} +8 ")
    raise "Problem editing #@root/src/#{file}" unless result
  rescue => err
    error(err)
  end

  ### browse

  def cmd_browse
    raise "Glitch: Got an argument" if arg != []
    @deploy ||= {}
    return puts red("\n  Deploy first.") unless @deploy[@view]

    lines = @deploy[@view]
    user, server, sroot, spath = *lines
    result = system("open 'http://#{server}/#{spath}'")
    raise "Problem opening http://#{server}/#{spath}" unless result
  rescue => err
    error(err)
  end

  ### open_local

  def open_local
    result = system("open #{@blog.viewdir(@view)}/index.html")
    raise "Problem opening #{@blog.viewdir(@view)}/index.html" unless result
  rescue => err
    error(err)
  end

  def cmd_deploy(arg)
    # TBD clunky FIXME 
    raise "Glitch: Got an argument" if arg != []
    @deploy ||= {}
    deployment = @blog.viewdir(@view) + "deploy"
    raise "File '#{deployment}' not found" unless File.exist?(deployment)

    lines = File.readlines(deployment).map {|x| x.chomp }
    @deploy[@view] = lines
    user, server, sroot, spath = *lines
    vdir = @blog.viewdir(@view)
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
    error(err)
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

  ### rebuild

  def cmd_rebuild(arg)
    raise "Glitch: Got an argument" if arg != []
    puts
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files.each {|file| rebuild_post(file) }
  rescue => err
    error(err)
  end

  ### relink

  def cmd_relink(arg)
    raise "Glitch: Got an argument" if arg != []
    @blog.views.each {|view| generate_index(view) }
  rescue => err
   error(err)
  end

#  ### publish?
#
#  def publish?
#    yn = ask(red("  Publish? y/n "))
#    yn.upcase == "Y"
#  end

  ### list_views

  def cmd_list_views(arg)
    abort "Config file not read"  unless @blog
    raise "Glitch: Got an argument" if arg != []
    puts
    @blog.views.each {|v| puts "  #{v}" }
  rescue => err
    error(err)
  end

  ### change_view

  def cmd_change_view(arg)
    if arg.empty?
      puts "\n  #@view"
    else
      arg = arg.first
      list = @blog.views.grep /^#{arg}/
      if list.size == 1
        @view = @blog.view = list.first
        puts red("\n  View: #{@view}") if arg != @view
      else
        puts "view #{arg.inspect} does not exist"
      end
    end
  rescue => err
    error(err)
  end

  ### new_view

  def cmd_new_view(arg)
    arg = arg.first
    @blog ||= open_blog
    arg ||= ask("New view: ")  # check validity later
    raise "view #{arg} already exists" if @blog.views.include?(arg)

    dir = @root + "/views/" + arg + "/"
    create_dir(dir + 'custom')
    create_dir(dir + 'assets')

    # Something more like this?  RuneBlog.new_view(arg)
    File.write(dir + "custom/blog_header.html",  RuneBlog::BlogHeader)
    File.write(dir + "custom/blog_trailer.html", RuneBlog::BlogTrailer)
    File.write(dir + "last_deployed", "Initial creation")
    @blog.views << arg
  rescue => err
    error(err)
  end

  ### import

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

  ### new_post

  def cmd_new_post(arg)
    raise "Glitch: Got an argument" if arg != []
    open_blog unless @blog
    @title = ask("Title: ")
    @today = Time.now.strftime("%Y%m%d")
    @date = Time.now.strftime("%Y-%m-%d")

    file = @blog.create_new_post(@title, @date, @view)
    edit_initial_post(file)
    process_post(file)  #- FIXME handle each view
    publish_post(@meta) # if publish?
  rescue => err
    error(err)
  end

  ### remove_multiple_posts
  
  def remove_multiple_posts(str)
    args = str.split
    args.each {|arg| remove_post(arg, false) }
  end

  ### remove_post

  #-- FIXME affects linking, building, deployment...

  def cmd_remove_post(arg, safe=true)
    arg = arg.first
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}"
    files = Find.find(@root).to_a
    files = files.grep(/#{tag}-/)
    return puts red("\n  No such post found (#{id})") if files.empty?

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

  def cmd_edit_post(arg)
    arg = arg.first
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}"
    files = Find.find(@root+"/src").to_a
    files = files.grep(/#{tag}-/)
    files = files.map {|f| File.basename(f) }
    return puts red("Multiple files: #{files}") if files.size > 1
    return puts red("\n  No such post found (#{id})") if files.empty?

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

  def cmd_list_posts(arg)
    raise "Glitch: Got an argument" if arg != []
    dir = @blog.viewdir(@view)
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

  def cmd_list_drafts(arg)
    raise "Glitch: Got an argument" if arg != []
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

  def cmd_INVALID(arg)
    puts "\n  Command '#{red(arg)}' was not understood."
  end

  def cmd_help(arg)
    raise "Glitch: Got an argument" if arg != []
    puts <<-EOS
  
    Commands:
  
       #{red('h, help       ')}    This message
       #{red('q, quit        ')}   Exit the program
       #{red('v, version    ')}    Print version information
  
       #{red('change view VIEW ')} Change current view
       #{red('cv VIEW          ')} Change current view
       #{red('new view         ')} Create a new view
       #{red('list views       ')} List all views available
       #{red('lsv              ')} Same as: list views
  
       #{red('p, post          ')} Create a new post
       #{red('new post         ')} Same as post (create a post)
       #{red('lsp, list posts  ')} List posts in current view
       #{red('lsd, list drafts ')} List all posts regardless of view
  
       #{red('rm ID            ')} Remove a post
       #{red('edit ID          ')} Edit a post
  
       #{red('preview          ')} Look at current (local) view in browser
       #{red('browse           ')} Look at current (deployed) view in browser
       #{red('relink           ')} Regenerate index for all views
       #{red('rebuild          ')} Regenerate all posts and relink
       #{red('deploy           ')} Deploy (current view)
    EOS
  end

end
