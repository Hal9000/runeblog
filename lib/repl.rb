require 'runeblog'
require 'global'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

make_exception(:PublishError,  "Error during publishing")
make_exception(:EditorProblem, "Could not edit $1")

module RuneBlog::REPL

  def edit_file(file)
    result = system!("#{@blog.editor} #{file}")
    raise EditorProblem(file) unless result
    sleep 0.1
    STDSCR.clear
  end

  def cmd_quit(arg, testing = false)
    check_empty(arg)
    RubyText.stop
    system!("tput clear")
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
    @out
  end

  def cmd_config(arg, testing = false)
    check_empty(arg)
    dir = @blog.view.dir
    items = ["themes/standard/blogview.lt3", "themes/standard/post-index.lt3"] 
    num, fname = STDSCR.menu(title: "Edit file:", items: items)
    edit_file("#{dir}/#{fname}")
  end

  # Currently not used
  def cmd_customize(arg, testing = false)
    # add extra views? add tags?
    puts "\n  This is still buggy.\n "
    return

    avail_tags = all_tags
    tags = STDSCR.multimenu(items: avail_tags)
    @blog.post_tags = tags
  end
  
  def cmd_tags(arg, testing = false)
    Dir.chdir(@blog.root + "/views/" + @blog.view.name)
    edit_file("tagpool")
  end

  def cmd_import(arg, testing = false)
    check_empty(arg)
    files = ask("\n  File(s) = ")
    system!("cp #{files} #{@blog.root}/views/#{@blog.view.name}/assets/")
  end

  def cmd_browse(arg, testing = false)
    reset_output
    check_empty(arg)
    url = @blog.view.publisher.url
    if url.nil?   
      output! "Publish first."
      puts "\n  Publish first."
      return @out
    end
    result = system!("open '#{url}'")
    raise CantOpen(url) unless result
    return @out
  end

  def cmd_preview(arg, testing = false)
    reset_output
    check_empty(arg)
    local = @blog.view.local_index
    result = system!("open #{local}")
    raise CantOpen(local) unless result
    @out
  end

  def cmd_publish(arg, testing = false)
# Future Hal says please refactor this
    puts unless testing
    reset_output
    check_empty(arg)
    unless @blog.view.can_publish?
      msg = "Can't publish... see globals.lt3"
      puts msg unless testing
      output! msg
      return @out
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
    return @out if files.empty?

    ret = RubyText.spinner(label: " Publishing... ") do
      @blog.view.publisher.publish(files, assets)  # FIXME weird?
    end
    return @out unless ret

    vdir = @blog.view.dir
    dump("fix this later", "#{vdir}/last_published")
    if ! testing || ! ret
      puts "  ...finished.\n " 
      output! "...finished.\n"
    end
    return @out
  end

  def cmd_rebuild(arg, testing = false)
    debug "Starting cmd_rebuild..."
    reset_output
    check_empty(arg)
    puts unless testing
    @blog.generate_view(@blog.view)
    @out
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
      return @out
    else
      if @blog.view?(arg)
        @blog.view = arg  # reads config
        output "View: " + @blog.view.name.to_s
        puts "\n  ", fx(arg, :bold), "\n" unless testing
      end
    end
    return @out
  end

  def cmd_new_view(arg, testing = false)
    reset_output
    @blog.create_view(arg)
    edit_file(@blog.view.dir/"themes/standard/global.lt3")
    @blog.change_view(arg)
    @out
  rescue ViewAlreadyExists
    puts 'Blog already exists'
  end

  def cmd_new_post(arg, testing = false)
    reset_output
    check_empty(arg)
    title = ask("\nTitle: ")
    @blog.create_new_post(title)
#   STDSCR.clear
    @out
  rescue => err
    puts err
    puts err.backtrace.join("\n")
  end

  def _remove_post(arg, testing=false)
    id = get_integer(arg)
    result = @blog.remove_post(id)
    puts "Post #{id} not found" if result.nil?
  end

  def cmd_remove_post(arg, testing = false)
puts "arg = #{arg.inspect} is a #{arg.class}"
    reset_output
    args = arg.split
    args.each do |x| 
      # FIXME
      ret = _remove_post(x.to_i, false)
      puts ret
      output ret
    end
    @out
  end

  #-- FIXME affects linking, building, publishing...

  def cmd_edit_post(arg, testing = false)
    reset_output
    id = get_integer(arg)
    # Simplify this
    tag = "#{'%04d' % id}"
    files = Find.find(@blog.root+"/drafts").to_a
    files = files.grep(/#{tag}-.*lt3/)
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
    draft = "#{@blog.root}/drafts/#{file}"
    result = edit_file(draft)
    @blog.generate_post(draft)
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
    @out
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
      puts "  No posts" unless testing
    else
      posts.each do |post| 
        outstr "  #{colored_slug(post)}\n" 
        base = post.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    @out
  end

  def cmd_list_drafts(arg, testing = false)
    reset_output
    check_empty(arg)
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      puts "\n  No drafts\n " unless testing
      return @out
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
    @out
  end

  def cmd_list_assets(arg, testing = false)
    reset_output
    check_empty(arg)
    dir = @blog.view.dir + "/assets"
    assets = Dir[dir + "/*"]
    if assets.empty?
      output! "No assets"
      puts "  No assets" unless testing
      return @out
    else
      puts unless testing
      assets.each do |name| 
        asset = File.basename(name)
        outstr asset
        puts "  ", fx(asset, Blue) unless testing
      end
    end
    puts unless testing
    @out
  end

  def cmd_ssh(arg, testing = false)
    pub = @blog.view.publisher
    system!("ssh #{pub.user}@#{pub.server}")
  end

  def cmd_INVALID(arg, testing = false)
    reset_output "\n  Command '#{arg}' was not understood."
    print fx("\n  Command ", :bold)
    print fx(arg, Red, :bold)
    puts fx(" was not understood.\n ", :bold)
    @out
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

*      config            Edit the publish file or the templates
*      customize         (BUGGY) Change set of tags, extra views
  
       p, post           Create a new post
       new post          Same as post (create a post)

*      import ASSETS     Import assets (images, etc.)

       lsp, list posts   List posts in current view

       lsd, list drafts  List all posts regardless of view
  
       delete ID [ID...] Remove multiple posts
       undelete ID       Undelete a post
       edit ID           Edit a post
  
       preview           Look at current (local) view in browser
       browse            Look at current (published) view in browser
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
    @out
  end

end

