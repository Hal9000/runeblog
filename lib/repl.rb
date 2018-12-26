require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

make_exception(:PublishError,  "Error during publishing")
# make_exception(:EditorProblem, "Could not edit $1")

module RuneBlog::REPL

  def edit_file(file)
    result = system("#{@blog.editor} #{file}")
    raise EditorProblem(file) unless result
    sleep 0.1
    STDSCR.clear
  end

  def cmd_quit(arg, testing = false)
    check_empty(arg)
#   system("tput rmcup")
    RubyText.stop
    system("tput clear")
    exit
  end

  def cmd_clear(arg, testing = false)
    check_empty(arg)
    STDSCR.cwin.clear
    STDSCR.cwin.refresh
  end

  def cmd_version(arg, testing = false)
    reset_output
    check_empty(arg)
    output RuneBlog::VERSION
    [true, @out]
  end

  def cmd_config(arg, testing = false)
    check_empty(arg)
    dir = @blog.view.dir
    items = ["publish", 
             "custom/blog_header.html", 
             "custom/blog_trailer.html", 
             "custom/post_template.html"] 
    num, fname = STDSCR.menu(title: "Edit file:", items: items)
    edit_file("#{dir}/#{fname}")
  end

  def cmd_browse(arg, testing = false)
    reset_output
    check_empty(arg)
    url = @blog.view.publisher.url
    # FIXME Bad logic here.
    if url.nil?   
      output! "Publish first."
      return [true, @out]
    end
    result = system("open '#{url}'")
    raise CantOpen(url) unless result
    nil
  end

  def cmd_preview(arg, testing = false)
    reset_output
    check_empty(arg)
    local = @blog.view.index
    result = system("open #{local}")
    raise CantOpen(local) unless result
  end

  def cmd_publish(arg, testing = false)  # FIXME non-string return expected in caller?
    puts unless testing
    reset_output
    check_empty(arg)
    unless @blog.view.can_publish?
      puts "Can't publish without entries in #{@blog.view.name}/publish" unless testing
      output! "Can't publish without entries in #{@blog.view.name}/publish"
      return [false, @out]
    end
    RubyText.spinner { @blog.view.publish }
    vdir = @blog.view.dir
    dump("fix this later", "#{vdir}/last_published")
    puts "  ...finished" unless testing
    output! "...finished.\n"
    return [false, @out]
  end

  def cmd_rebuild(arg, testing = false)
    debug "Starting cmd_rebuild..."
    reset_output
    check_empty(arg)
    puts unless testing
debug "cp1"
    files = @blog.find_src_slugs
debug "cp2"
    files.each {|file| @blog.rebuild_post(file) }
debug "cp3"
    nil
  end

  def cmd_relink(arg, testing = false)
    reset_output
    check_empty(arg)
    @blog.relink
    nil
  end

  def cmd_change_view(arg, testing = false)
    reset_output
    # Simplify this
    if arg.nil?
      viewnames = @blog.views.map {|x| x.name }
      n = viewnames.find_index(@blog.view.name)
      name = @blog.view.name
      k, name = STDSCR.menu(title: "Views", items: viewnames, curr: n) unless testing
      @blog.view = name
      output name + "\n"
      puts "\n  ", fx(name, :bold), "\n" unless testing
      return [false, @out]
    else
      if @blog.view?(arg)
        @blog.view = arg  # reads config
        output red("View: ") + bold(@blog.view.name.to_s)  # FIXME?
      end
    end
    return [false, @out]
  end

  def cmd_new_view(arg, testing = false)
    reset_output
    @blog.create_view(arg)
    resp = yesno("Add publishing info now? ")
    @blog.view.publisher = ask_publishing_info
    write_config(@blog.view.publisher,  @blog.view.dir + "/publish")  # change this?
    nil
  end

  def cmd_new_post(arg, testing = false)
    reset_output
    check_empty(arg)
    title = ask("\nTitle: ")
    @blog.create_new_post(title)
    STDSCR.clear
    nil
  rescue => err
    puts err
    puts err.backtrace.join("\n")
  end

  def cmd_kill(arg, testing = false)
    reset_output
    args = arg.split
    args.each do |x| 
      # FIXME
      ret = cmd_remove_post(x.to_i, false)
      output ret
    end
    return [true, @out]
  end

  #-- FIXME affects linking, building, publishing...

  def cmd_remove_post(arg, testing = false, safe=true)
    # FIXME - 'safe' is no longer a thing
    reset_output
    id = get_integer(arg)
    result = @blog.remove_post(id)
    output! "Post #{id} not found" if result.nil?
    return [true, @out]
  end

  #-- FIXME affects linking, building, publishing...

  def cmd_edit_post(arg, testing = false)
    reset_output
    id = get_integer(arg)
    # Simplify this
    tag = "#{'%04d' % id}"
    files = Find.find(@blog.root+"/src").to_a
    files = files.grep(/#{tag}-/)
    files = files.map {|f| File.basename(f) }
    return [true, "Multiple files: #{files}"] if files.size > 1
    return [true, "\n  Can't edit post #{id}"] if files.empty?

    file = files.first
    result = edit_file("#{@blog.root}/src/#{file}")
    @blog.rebuild_post(file)
    nil
  end

  def cmd_list_views(arg, testing = false)
    reset_output("\n")
    check_empty(arg)
    puts unless testing
    @blog.views.each do |v| 
      v = v.to_s
      v = fx(v, :bold) if v == @blog.view.name
      print "  "
      output v + "\n"
      puts v unless testing
    end
    puts unless testing
    return [false, @out]
  end

  def cmd_list_posts(arg, testing = false)
    reset_output
    check_empty(arg)
    posts = @blog.posts  # current view
    str = @blog.view.name + ":\n"
    output str
    puts unless testing
    print "  "
    puts fx(str, :bold) unless testing
    if posts.empty?
      output! bold("No posts")
      puts fx("  No posts", :bold) unless testing
    else
      posts.each do |post| 
        outstr "  #{colored_slug(post)}\n" 
        base = post.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        print "  "
        puts fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    return [false, @out]
  end

  def cmd_list_drafts(arg, testing = false)
    reset_output
    check_empty(arg)
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      puts "  No drafts" unless testing
      return [true, @out]
    else
      puts unless testing
      drafts.each do |draft| 
        outstr "  #{colored_slug(draft.sub(/.lt3$/, ""))}\n" 
        base = draft.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        print "  "
        puts fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    return [false, @out]
  end

  def cmd_INVALID(arg, testing = false)
    reset_output "\n  Command '#{red(arg)}' was not understood."
    return [true, @out]
  end

  def cmd_help(arg, testing = false)
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
       #{red('undelete ID      ')} Undelete a post
       #{red('edit ID          ')} Edit a post
  
       #{red('preview          ')} Look at current (local) view in browser
       #{red('browse           ')} Look at current (published) view in browser
       #{red('relink           ')} Regenerate index for all views
       #{red('rebuild          ')} Regenerate all posts and relink
       #{red('publish          ')} Publish (current view)
    EOS
    return [true, @out]
  end

end
