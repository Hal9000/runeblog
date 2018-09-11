require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

module RuneBlog::REPL

  def cmd_quit(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    puts "\n "
    exit
  end

  def cmd_version(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    return "\n  " + RuneBlog::VERSION
  end

  def new_blog!(arg)   # FIXME weird?
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    return if RuneBlog.exist?
    yn = yesno(red("  No .blog found. Create new blog? "))
    RuneBlog.create_new_blog if yn
  rescue => err
    error(err)
  end 

  def open_blog # Crude - FIXME later
    @blog = RuneBlog.new
    @view = @blog.view     # current view
    @sequence = @blog.sequence
    @root = @blog.root
    @blog
  rescue => err
    error(err)
  end

  def cmd_browse
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    @deploy ||= {}
    return puts red("\n  Deploy first.") unless @deploy[@view]

    lines = @deploy[@view]
    user, server, sroot, spath = *lines
    result = system("open 'http://#{server}/#{spath}'")
    raise "Problem opening http://#{server}/#{spath}" unless result
    nil
  rescue => err
    error(err)
  end

  def cmd_open_local
    result = system("open #{@blog.viewdir(@view)}/index.html")
    raise "Problem opening #{@blog.viewdir(@view)}/index.html" unless result
    nil
  rescue => err
    error(err)
  end

  def cmd_deploy(arg)  # FIXME non-string return expected in caller?
    # TBD clunky FIXME 
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
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
    if files.empty?
      puts red("\n  No files to deploy") 
      return nil
    end

    out = "\n  Files:"
    files.each {|f| out << ("    " + f + "\n") }
    out << "\n"
    dir = "#{sroot}/#{spath}"
    # FIXME - may or may not already exist
    result = system("ssh root@#{server} mkdir #{dir}") 

    cmd = "scp -r #{files.join(' ')} root@#{server}:#{dir} >/dev/null 2>&1"
    out << red("\n  Deploying #{files.size} files...\n")
    result = system(cmd)
    raise "Problem occurred in deployment" unless result

    File.write("#{vdir}/last_deployed", files)
    out << red("finished.\n")
    out
  rescue => err
    error(err)
  end

  def cmd_rebuild(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    puts
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files.each {|file| rebuild_post(file) }
    nil
  rescue => err
    error(err)
  end

  def cmd_relink(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    @blog.views.each {|view| generate_index(view) }
    nil
  rescue => err
   error(err)
  end

  def cmd_list_views(arg)
    abort "Config file not read"  unless @blog
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    out = "\n"
    @blog.views.each {|v| out << "  #{v}\n" }
    out
  rescue => err
    error(err)
  end

  def cmd_change_view(arg)
    if arg.nil?
      return "\n  #{@blog.view}"
    else
      out = ""
      list = @blog.views.grep /^#{arg}/
      if list.size == 1
        @view = @blog.view = list.first
        out << red("\n  View: #{@view}\n") if arg != @view
      else
        out << "view #{arg.inspect} does not exist\n"
      end
    end
    out
  rescue => err
    error(err)
  end

  def cmd_new_view(arg)
    @blog ||= open_blog
    arg ||= ask("New view: ")  # check validity later
    raise "view #{arg} already exists" if @blog.views.include?(arg)

    dir = @root + "/views/" + arg + "/"
    create_dir(dir + 'custom')
    create_dir(dir + 'assets')
    File.open(dir + "deploy") { }  # FIXME

    # Something more like this?  RuneBlog.new_view(arg)
    File.write(dir + "custom/blog_header.html",  RuneBlog::BlogHeader)
    File.write(dir + "custom/blog_trailer.html", RuneBlog::BlogTrailer)
    File.write(dir + "last_deployed", "Initial creation")
    @blog.views << arg
  rescue => err
    error(err)
  end

  def cmd_new_post(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    open_blog unless @blog   # duh?
    @title = ask("Title: ")
    @blog.create_new_post(@title)
  rescue => err
    error(err)
  end

  def cmd_kill(arg)
    args = arg.split
    args.each {|x| cmd_remove_post([x], false) }
    nil
  rescue => err
    error(err)
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_remove_post(arg, safe=true)
    out = ""
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}"
    files = Find.find(@root).to_a
    files = files.grep(/#{tag}-/)
    if files.empty?
      out = red("\n  No such post found (#{id})") 
      return out
    end

    if safe
      out << "\n"
      files.each {|f| out << "  #{f}\n" }
      puts out
      out = ""
      ques = files.size > 1 ? "\n  Delete all these?\n " : "\n  Delete?\n "
      yn = ask red(ques)
      if yn.downcase == "y"
        result = system("rm -rf #{files.join(' ')}")
        raise "Problem deleting file(s)" unless result
        out << red("\n  Deleted\n")
      else
        out << red("\n  No action taken\n")
      end
    else
      result = system("rm -rf #{files.join(' ')}")
      out << red("\n  Deleted:\n")
      files.each {|f| out << "    #{f}\n" }
      raise "Problem mass-deleting file(s)" unless result
    end
    out
  rescue => err
    error(err)
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_edit_post(arg)
    id = Integer(arg) rescue raise("'#{arg}' is not an integer")
    tag = "#{'%04d' % id}"
    files = Find.find(@root+"/src").to_a
    files = files.grep(/#{tag}-/)
    files = files.map {|f| File.basename(f) }
    return red("Multiple files: #{files}") if files.size > 1
    return red("\n  No such post found (#{id})") if files.empty?

    file = files.first
    result = system("vi #@root/src/#{file}")
    raise "Problem editing #{file}" unless result

    rebuild_post(file)
    nil
  rescue => err
    error(err)
  end

  def cmd_list_posts(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    out = ""
    @view = @blog.view
    dir = @blog.viewdir(@view)
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*/)
      if posts.empty?
        out << ("\n  " + @view + ":" + red("  No posts\n"))
      else
        out << ("\n  " + @view + ":\n ")
        posts.each {|post| out << "  #{colored_slug(post)}\n" }
      end
    end
    out
  rescue => err
    error(err)
  end

  def cmd_list_drafts(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    out = ""
    dir = "#@root/src"
    Dir.chdir(dir) do
      posts = Dir.entries(".").grep(/^0.*.lt3/)
      out << "\n"
      if posts.empty?
        return red("  No posts")
      else
        posts.each {|post| out << "  #{colored_slug(post.sub(/.lt3$/, ""))}\n" }
      end
    end
    out
  rescue => err
    error(err)
  end

  def cmd_INVALID(arg)
    return "\n  Command '#{red(arg)}' was not understood."
  end

  def cmd_help(arg)
    raise "Glitch: #{__callee__} got arg #{arg.inspect}" unless arg.nil?
    out = <<-EOS
  
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
    out
  end

end
