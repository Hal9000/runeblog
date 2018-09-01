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

require 'helpers-repl'  # FIXME structure

module RuneBlog::REPL

  def cmd_quit(arg)
    raise "Glitch: Got an argument" if arg != []
    puts "\n "
    exit
  end

  def cmd_version(arg)
    raise "Glitch: Got an argument" if arg != []
    puts "\n  " + RuneBlog::VERSION
  end

  def new_blog!(arg)   # FIXME weird?
    raise "Glitch: Got an argument" if arg != []
    return if RuneBlog.exist?
    yn = yesno(red("  No .blog found. Create new blog? "))
    RuneBlog.create_new_blog if yn
  rescue => err
    error(err)
  end 

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

  def edit_initial_post(file)
    result = system("vi #@root/src/#{file} +8 ")
    raise "Problem editing #@root/src/#{file}" unless result
  rescue => err
    error(err)
  end

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

  def cmd_open_local
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

  def cmd_relink(arg)
    raise "Glitch: Got an argument" if arg != []
    @blog.views.each {|view| generate_index(view) }
  rescue => err
   error(err)
  end

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
    publish_post(@meta)
  rescue => err
    error(err)
  end

  def cmd_kill(arg)
    args = arg.first.split
    args.each {|x| cmd_remove_post([x], false) }
  end

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
    error(err)
  end

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
    error(err)
  end

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
  rescue => err
    error(err)
  end

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
