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
    puts fx("\n  RuneBlog", :bold), fx(" v #{RuneBlog::VERSION}\n", Red) unless testing
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

  def cmd_customize(arg, testing = false)
    # add extra views? add tags?
    Dir.chdir(@blog.root + "/views/" + @blog.view.name)
    others = @blog.views - [@blog.view]
    others.map!(&:name)
    viewlist = STDSCR.multimenu(items: others)
    @blog.post_views = viewlist
    tags = File.readlines("tagpool").map(&:chomp)
    return if tags.empty?
    taglist = STDSCR.multimenu(items: tags)
    @blog.post_tags = taglist
  end
  
  def cmd_tags(arg, testing = false)
    Dir.chdir(@blog.root + "/views/" + @blog.view.name)
    edit_file("tagpool")
  end

  def cmd_import(arg, testing = false)
    check_empty(arg)
    files = ask("\n  File(s) = ")
    system("cp #{files} #{@blog.root}/views/#{@blog.view.name}/assets/")
  end

  def cmd_browse(arg, testing = false)
    reset_output
    check_empty(arg)
    url = @blog.view.publisher.url
    if url.nil?   
      output! "Publish first."
      puts "\n  Publish first."
      return [false, @out]
    end
    result = system("open '#{url}'")
    raise CantOpen(url) unless result
    return [true, @out]
  end

  def cmd_preview(arg, testing = false)
    reset_output
    check_empty(arg)
    local = @blog.view.index
    result = system("open #{local}")
    raise CantOpen(local) unless result
    [true, @out]
  end

  def cmd_publish(arg, testing = false)
    puts unless testing
    reset_output
    check_empty(arg)
    unless @blog.view.can_publish?
      puts "Can't publish without entries in #{@blog.view.name}/publish" unless testing
      output! "Can't publish without entries in #{@blog.view.name}/publish"
      return [false, @out]
    end
    # Need to check dirty/clean status first
    dirty, all, assets = @blog.view.publishable_files
    files = dirty
    if dirty.empty?
      puts fx("\n  No files are out of date." + " "*20, :bold)
      print "  Publish anyway? "
      yn = RubyText.gets.chomp
      files = all if yn == "y"
    end
    return [false, @out] if files.empty?

    ret = RubyText.spinner(label: " Publishing... ") do
      @blog.view.publisher.publish(files, assets)  # FIXME weird?
    end
    return [false, @out] unless ret
    vdir = @blog.view.dir
    dump("fix this later", "#{vdir}/last_published")
    if ! testing || ! ret
      puts "  ...finished.\n " 
      output! "...finished.\n"
    end
    return [true, @out]
  end

  def cmd_rebuild(arg, testing = false)
    debug "Starting cmd_rebuild..."
    reset_output
    check_empty(arg)
    puts unless testing
    files = @blog.find_src_slugs
    files.each do |file| 
      @blog.rebuild_post(file)
    end
    File.write("last_rebuild", Time.now)
    [true, @out]
  end

  def cmd_relink(arg, testing = false)
    reset_output
    check_empty(arg)
    @blog.relink
    [true, @out]
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
        output "View: " + @blog.view.name.to_s
        puts "\n  ", fx(arg, :bold), "\n" unless testing
      end
    end
    return [true, @out]
  end

  def cmd_new_view(arg, testing = false)
    reset_output
    @blog.create_view(arg)
    resp = yesno("Add publishing info now? ")
    @blog.view.publisher = ask_publishing_info
    write_config(@blog.view.publisher,  @blog.view.dir + "/publish")  # change this?
    [true, @out]
  end

  def cmd_new_post(arg, testing = false)
    reset_output
    check_empty(arg)
    title = ask("\nTitle: ")
    @blog.create_new_post(title)
    STDSCR.clear
    [true, @out]
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
      puts ret
      output ret
    end
    [true, @out]
  end

  #-- FIXME affects linking, building, publishing...

  def cmd_remove_post(arg, testing = false, safe=true)
    # FIXME - 'safe' is no longer a thing
    reset_output
    id = get_integer(arg)
    result = @blog.remove_post(id)
    output! "Post #{id} not found" if result.nil?
#   puts "Post #{id} not found" if result.nil?
    [true, @out]
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
    if files.size > 1
      msg = "Multiple files: #{files}"
      output msg
      puts msg unless testing
      return [false, msg]
    end
    if files.empty?
      msg = "\n  Can't edit post #{id}"
      output msg
      puts msg unless testing
      return [false, msg]
    end

    file = files.first
    result = edit_file("#{@blog.root}/src/#{file}")
    @blog.rebuild_post(file)
    [true, @out]
  end

  def cmd_list_views(arg, testing = false)
    reset_output("\n")
    check_empty(arg)
    puts unless testing
    @blog.views.each do |v| 
      v = v.to_s
      v = fx(v, :bold) if v == @blog.view.name
      output v + "\n"
      puts "  ", v unless testing
    end
    puts unless testing
    [true, @out]
  end

  def cmd_list_posts(arg, testing = false)
    reset_output
    check_empty(arg)
    posts = @blog.posts  # current view
    str = @blog.view.name + ":\n"
    output str
    puts unless testing
    puts "  ", fx(str, :bold) unless testing
    if posts.empty?
      output! "No posts"
      puts fx("  No posts", :bold) unless testing
    else
      posts.each do |post| 
        outstr "  #{colored_slug(post)}\n" 
        base = post.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    [true, @out]
  end

  def cmd_list_drafts(arg, testing = false)
    reset_output
    check_empty(arg)
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      puts "  No drafts" unless testing
      return [false, @out]
    else
      puts unless testing
      drafts.each do |draft| 
        outstr "  #{colored_slug(draft.sub(/.lt3$/, ""))}\n" 
        base = draft.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    [true, @out]
  end

  def cmd_list_assets(arg, testing = false)
    reset_output
    check_empty(arg)
    dir = @blog.view.dir + "/assets"
    assets = Dir[dir + "/*"]
    if assets.empty?
      output! "No assets"
      puts "  No assets" unless testing
      return [false, @out]
    else
      puts unless testing
      assets.each do |name| 
        asset = File.basename(name)
        outstr asset
        puts "  ", fx(asset, Blue) unless testing
      end
    end
    puts unless testing
    [true, @out]
  end

  def cmd_ssh(arg, testing = false)
    pub = @blog.view.publisher
    system("ssh #{pub.user}@#{pub.server}")
  end

  def cmd_INVALID(arg, testing = false)
    reset_output "\n  Command '#{arg}' was not understood."
    print fx("\n  Command ", :bold)
    print fx(arg, Red, :bold)
    puts fx(" was not understood.\n ", :bold)
    [true, @out]
  end

  def cmd_help(arg, testing = false)
    reset_output 
    check_empty(arg)
    msg = <<-EOS

       Commands:
  
       h, help           This message
       q, quit           Exit the program
       v, version        Print version information
  
       change view VIEW  Change current view
       cv VIEW           Change current view

       new view          Create a new view

       list views        List all views available
       lsv               Same as: list views

       customize         Change set of tags, extra views
  
       p, post           Create a new post
       new post          Same as post (create a post)

       import ASSETS     Import assets (images, etc.)

       lsp, list posts   List posts in current view

       lsd, list drafts  List all posts regardless of view
  
       rm ID             Remove a post
       kill ID ID ID...  Remove multiple posts
       undelete ID       Undelete a post
       edit ID           Edit a post
  
       preview           Look at current (local) view in browser
       browse            Look at current (published) view in browser
       relink            Regenerate index for all views
       rebuild           Regenerate all posts and relink
       publish           Publish (current view)
       ssh               Login to remote server
    EOS
    output msg
    msg.each_line do |line|
      next if testing
      line.chomp!
      s1, s2 = line[0..22], line[23..-1]
      print fx(s1, :bold)
      puts s2
    end
    puts unless testing
    [true, @out]
  end

end
