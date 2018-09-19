require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

module RuneBlog::REPL

# @blog = open_blog

  def cmd_quit(arg)
    check_empty(arg)
    abort "\n "
  end

  def cmd_version(arg)
    reset_output
    check_empty(arg)
    output RuneBlog::VERSION
    return @out
  end

  def cmd_browse
    reset_output
    check_empty(arg)
    url = @blog.deployment_url
    if url.nil?
      output! "Deploy first."
      return @out
    end
    result = system("open '#{url}'")
    raise CantOpen, url unless result
    nil
  rescue => err
    error(err)
  end

  def cmd_open_local
    reset_output
    local = @blog.viewdir(@view) + "/index.html"
    result = system("open #{local}")
    raise CantOpen, local unless result
  rescue => err
    error(err)
  end

  def cmd_deploy(arg)  # FIXME non-string return expected in caller?
    # TBD clunky FIXME 
    reset_output
    check_empty(arg)
    user, server, sroot, spath = *@deploy[@view]
    if files.empty?
      output! "No files to deploy"
      return @out
    end

    output "Files:"
    files.each {|f| output "    #{f}\n" }
    output_newline
    dir = "#{sroot}/#{spath}"
    # FIXME - may or may not already exist
    result = system("ssh root@#{server} mkdir #{dir}") 
    # ^ needs -c?? 

    cmd = "scp -r #{files.join(' ')} root@#{server}:#{dir} >/dev/null 2>&1"
    output! "Deploying #{files.size} files...\n"
    result = system(cmd)
    raise "Problem occurred in deployment" unless result

    File.write("#{vdir}/last_deployed", files)
    output! "...finished.\n"
    @out
  rescue => err
    error(err)
  end

  def cmd_rebuild(arg)
    reset_output
    check_empty(arg)
    puts
    # Simplify this
    files = Dir.entries("#@root/src/").grep /\d\d\d\d.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files.each {|file| rebuild_post(file) }
    nil
  rescue => err
    error(err)
  end

  def cmd_relink(arg)
    reset_output
    check_empty(arg)
    @blog.views.each {|view| generate_index(view) }
    nil
  rescue => err
   error(err)
  end

  def cmd_list_views(arg)
    reset_output("\n")
    check_empty(arg)
    abort "Config file not read"  unless @blog
    @blog.views.each do |v| 
      v = bold(v) if v == @blog.view
      outstr "  #{v}\n"
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_change_view(arg)
    reset_output
    # Simlify this
    if arg.nil?
      output "#{@blog.view}"
      return @out
    else
      list = @blog.views.grep /^#{arg}/
      if list.size == 1
        @view = @blog.view = list.first
        output! "View: #{@view}\n" if arg != @view
      else
        output! "view #{arg.inspect} does not exist\n"
      end
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_new_view(arg)
    reset_output
    arg ||= ask("New view: ")  # check validity later
    @blog.create_view(arg)
    return nil
  rescue => err
    error(err)
  end

  def cmd_new_post(arg)
    reset_output
    check_empty(arg)
    @title = ask("Title: ")
    @blog.create_new_post(@title)
    return nil
  rescue => err
    error(err)
  end

  def cmd_kill(arg)
    reset_output
    args = arg.split
    args.each {|x| cmd_remove_post([x], false) }
    return nil
  rescue => err
    error(err)
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_remove_post(arg, safe=true)
    reset_output
    id = get_integer(arg)
    files = @blog.files_by_id(id)
    if files.empty?
      output! "No such post found (#{id})"
      return @out
    end

    if safe
      output_newline
      files.each {|f| outstr "  #{f}\n" }
      reset_output
      ques = "\n  Delete?\n "
      ques.sub!(/\?/, " all these?") if files.size > 1
      yes = yesno red(ques)
      if yes
        result = system("rm -rf #{files.join(' ')}")
        error_cant_delete(files) unless result
        output! "Deleted\n"
      else
        output! "No action taken\n"
      end
    else
      result = system("rm -rf #{files.join(' ')}")
      error_cant_delete(files) unless result
      output! "Deleted:\n"
      files.each {|f| output "    #{f}\n" }
    end
    @out
  rescue ArgumentError => err
    puts err
  rescue CantDelete => err
    puts err
  rescue => err
    error(err)
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_edit_post(arg)
    reset_output
    id = get_integer(arg)
    # Simlify this
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
    check_empty(arg)
    reset_output
    posts = @blog.posts  # current view
    output @view + ":\n"
    if posts.empty?
      output! "No posts\n"
    else
      posts.each {|post| outstr "  #{colored_slug(post)}\n" }
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_list_drafts(arg)
    check_empty(arg)
    reset_output
    output_newline
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      return @out
    else
      drafts.each do |draft| 
        outstr "  #{colored_slug(draft.sub(/.lt3$/, ""))}\n" 
      end
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_INVALID(arg)
    reset_output "\n  Command '#{red(arg)}' was not understood."
    return @out
  end

  def cmd_help(arg)
    reset_output 
    check_empty(arg)
    output(<<-EOS)
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
       #{red('kill ID ID ID... ')} Remove multiple posts
       #{red('edit ID          ')} Edit a post
  
       #{red('preview          ')} Look at current (local) view in browser
       #{red('browse           ')} Look at current (deployed) view in browser
       #{red('relink           ')} Regenerate index for all views
       #{red('rebuild          ')} Regenerate all posts and relink
       #{red('deploy           ')} Deploy (current view)
    EOS
    @out
  end

  ## Funky stuff -- needs to move?

  def new_blog!(arg)   # FIXME weird?
    check_empty(arg)
    return if RuneBlog.exist?
    yes = yesno(red("  No .blog found. Create new blog? "))
    RuneBlog.create_new_blog if yes
  rescue => err
    error(err)
  end 

  def open_blog # Crude - FIXME later
    @blog = RuneBlog.new
    @view = @blog.view     # current view
    @sequence = @blog.sequence
    @root = @blog.root
    @deploy ||= {}
    @blog.views.each do |view|
      deployment = @blog.viewdir(@view) + "deploy"
      check_file_exists(deployment)
      lines = File.readlines(deployment).map {|x| x.chomp }
      @deploy[@view] = lines
    end
    @blog
  rescue => err
    error(err)
  end

end
