require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

module RuneBlog::REPL

  def cmd_quit(arg)
    check_empty(arg)
    system("tput rmcup")
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
    url = @blog.view.deployer.url
    # FIXME Bad logic here.
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

  def cmd_preview(arg)
    reset_output
    check_empty(arg)
    local = @blog.view.index
    result = system("open #{local}")
    raise CantOpen, local unless result
  rescue => err
    error(err)
  end

  def cmd_deploy(arg)  # FIXME non-string return expected in caller?
    reset_output
    check_empty(arg)
    @blog.view.deploy
    user, server, sroot, spath = *@deploy[@blog.view]
    if files.empty?    # FIXME  baloney
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
    files = @blog.find_src_slugs
    files.each {|file| @blog.rebuild_post(file) }
    nil
  rescue => err
    error(err)
  end

  def cmd_relink(arg)
    reset_output
    check_empty(arg)
    @blog.relink
    nil
  rescue => err
   error(err)
  end

  def cmd_list_views(arg)
    reset_output("\n")
    check_empty(arg)
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
    # Simplify this
    if arg.nil?
      output bold(@blog.view)
      return @out
    else
      if @blog.view?(arg)
        @blog.view = arg  # reads config
        output red("View: ") + bold(@blog.view)
      end
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_new_view(arg)
    reset_output
    @blog.create_view(arg)
    resp = yesno("Add deployment info now? ")
    @blog.view.deployer = ask_deployment_info
    write_config(@blog.view.deployer,  @blog.view.dir + "/deploy")  # change this?
    nil
  rescue => err
    error(err)
  end

  def cmd_new_post(arg)
    reset_output
    check_empty(arg)
    title = ask("\nTitle: ")
    meta = OpenStruct.new
    meta.title = title
    @blog.create_new_post(meta)
    nil
  rescue => err
    error(err)
  end

  def cmd_kill(arg)
    reset_output "\n"
    args = arg.split
    args.each do |x| 
      # FIXME
      ret = cmd_remove_post(x.to_i, false)
      output ret
    end
    @out
  rescue => err
    error(err)
    puts err.backtrace
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_remove_post(arg, safe=true)
    # FIXME - 'safe' is no longer a thing
    reset_output
    id = get_integer(arg)
    result = @blog.remove_post(id)
    if result.nil?
      output! "Post #{id} not found"
      return @out
    end
    @out
  rescue ArgumentError => err
    puts err
    puts err.backtrace
  rescue CantDelete => err
    puts err
    puts err.backtrace
  rescue => err
    error(err)
    puts err.backtrace
  end

  #-- FIXME affects linking, building, deployment...

  def cmd_edit_post(arg)
    reset_output
    id = get_integer(arg)
    # Simplify this
    tag = "#{'%04d' % id}"
    files = Find.find(@blog.root+"/src").to_a
    files = files.grep(/#{tag}-/)
    files = files.map {|f| File.basename(f) }
    return red("Multiple files: #{files}") if files.size > 1
    return red("\n  Can't edit post #{id}") if files.empty?

    file = files.first
    result = system("vi #{@blog.root}/src/#{file}")
    raise "Problem editing #{file}" unless result

    @blog.rebuild_post(file)
    nil
  rescue => err
    error(err)
  end

  def cmd_list_posts(arg)
    check_empty(arg)
    reset_output
    posts = @blog.posts  # current view
    output bold(@blog.view.name) + ":"
    if posts.empty?
      output! bold("No posts")
    else
      output_newline
      posts.each {|post| outstr "  #{colored_slug(post)}\n" }
    end
    @out
  rescue => err
    error(err)
  end

  def cmd_list_drafts(arg)
    check_empty(arg)
    reset_output
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      return @out
    else
      output_newline
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

end
